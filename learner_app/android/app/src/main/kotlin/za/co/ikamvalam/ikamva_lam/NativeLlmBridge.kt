package za.co.ikamvalam.ikamva_lam

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig as LiteRtEngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * MethodChannel + EventChannel bridge: **LiteRT-LM** for `.litertlm`, **MediaPipe**
 * `LlmInference` for `.task` / `.bin` / `.tflite`.
 */
object NativeLlmBridge {
    private const val TAG = "NativeLlmBridge"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var appContext: Context? = null
    @Volatile private var liteRtEngine: Engine? = null
    @Volatile private var mediaPipeLlm: LlmInference? = null
    @Volatile private var loadedPath: String? = null

    private val streamSink = AtomicReference<EventChannel.EventSink?>(null)

    /** In-flight stream job — cancelled from [EventChannel.StreamHandler.onCancel] (Req 4.4). */
    private class ActiveStream {
        @Volatile var cancelled: Boolean = false
        var mpSession: LlmInferenceSession? = null
        var liteRtConversation: Conversation? = null
    }

    private val activeStream = AtomicReference<ActiveStream?>(null)

    fun register(messenger: BinaryMessenger, context: Context) {
        appContext = context.applicationContext
        val appCtx = appContext!!

        MethodChannel(messenger, "za.co.ikamvalam/native_llm").setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    @Suppress("UNCHECKED_CAST")
                    val loadArgs = call.arguments as? Map<String, Any?>
                    val rawPath = loadArgs?.get("modelPath")
                    if (rawPath == null || rawPath !is String || rawPath.isBlank()) {
                        result.error("bad_args", "missing or invalid modelPath", null)
                    } else {
                        executor.execute {
                            try {
                                handleLoad(appCtx, call)
                                mainHandler.post { result.success(null) }
                            } catch (e: Exception) {
                                Log.e(TAG, "loadModel failed", e)
                                mainHandler.post {
                                    result.error("load_failed", e.message, null)
                                }
                            }
                        }
                    }
                }
                "closeModel" -> executor.execute {
                    try {
                        closeAllEngines()
                    } finally {
                        mainHandler.post { result.success(null) }
                    }
                }
                "generate" -> executor.execute {
                    try {
                        val text = generateSync(call)
                        mainHandler.post { result.success(text) }
                    } catch (e: Exception) {
                        Log.e(TAG, "generate failed", e)
                        mainHandler.post {
                            result.error("generate_failed", e.message, null)
                        }
                    }
                }
                else -> mainHandler.post { result.notImplemented() }
            }
        }

        EventChannel(messenger, "za.co.ikamvalam/native_llm_stream").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    streamSink.set(events)
                    executor.execute {
                        try {
                            generateStream(arguments, events)
                        } catch (e: Exception) {
                            Log.e(TAG, "stream outer failed", e)
                            mainHandler.post {
                                events?.error("stream_failed", e.message, null)
                            }
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    val job = activeStream.getAndSet(null)
                    job?.cancelled = true
                    // Do not schedule on [executor]: the stream may be holding that thread on await.
                    job?.mpSession?.cancelGenerateResponseAsync()
                    runCatching { job?.liteRtConversation?.close() }
                    streamSink.set(null)
                }
            },
        )
    }

    private fun closeAllEngines() {
        runCatching { liteRtEngine?.close() }
        liteRtEngine = null
        runCatching { mediaPipeLlm?.close() }
        mediaPipeLlm = null
        loadedPath = null
    }

    private fun handleLoad(context: Context, call: MethodCall) {
        closeAllEngines()
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as Map<String, Any?>
        val path = args["modelPath"] as String
        val maxTokens = (args["maxTokens"] as Number).toInt()
        val preferGpu = args["preferGpu"] as Boolean
        val supportImage = args["supportImage"] as Boolean
        val supportAudio = args["supportAudio"] as Boolean
        val maxNumImages = (args["maxNumImages"] as Number).toInt()

        val f = File(path)
        if (!f.exists()) throw IllegalArgumentException("Model not found: $path")

        if (path.endsWith(".litertlm", ignoreCase = true)) {
            val backend = if (preferGpu) Backend.GPU() else Backend.CPU()
            val visionBackend =
                if (supportImage && maxNumImages > 0) backend else null
            val audioBackend =
                if (supportAudio) Backend.CPU() else null
            val cfg = LiteRtEngineConfig(
                modelPath = path,
                backend = backend,
                visionBackend = visionBackend,
                audioBackend = audioBackend,
                maxNumTokens = maxTokens,
                cacheDir = context.cacheDir.absolutePath,
            )
            val eng = Engine(cfg)
            runBlocking { eng.initialize() }
            liteRtEngine = eng
        } else {
            val optionsBuilder = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(path)
                .setMaxTokens(maxTokens)
                .apply {
                    if (preferGpu) {
                        setPreferredBackend(LlmInference.Backend.GPU)
                    } else {
                        setPreferredBackend(LlmInference.Backend.CPU)
                    }
                    if (supportImage && maxNumImages > 0) {
                        setMaxNumImages(maxNumImages)
                    }
                    if (supportAudio) {
                        setAudioModelOptions(
                            com.google.mediapipe.tasks.genai.llminference.AudioModelOptions.builder()
                                .build(),
                        )
                    }
                }
            mediaPipeLlm = LlmInference.createFromOptions(context, optionsBuilder.build())
        }
        loadedPath = path
        Log.i(TAG, "Loaded model at $path")
    }

    private fun generateSync(call: MethodCall): String {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as Map<String, Any?>
        val prompt = args["prompt"] as String
        val temperature = (args["temperature"] as Number).toFloat()
        val topK = (args["topK"] as Number).toInt()
        val topP = (args["topP"] as Number).toDouble()
        val randomSeed = (args["randomSeed"] as Number).toInt()
        val enableThinking = args["enableThinking"] as Boolean

        val path = loadedPath ?: throw IllegalStateException("Model not loaded")

        return if (path.endsWith(".litertlm", ignoreCase = true)) {
            litertGenerate(prompt, temperature, topK, topP, enableThinking)
        } else {
            mediaPipeGenerate(prompt, temperature, topK, topP, randomSeed, enableThinking)
        }
    }

    private fun litertGenerate(
        prompt: String,
        temperature: Float,
        topK: Int,
        topP: Double,
        enableThinking: Boolean,
    ): String {
        val engine = liteRtEngine ?: throw IllegalStateException("LiteRT engine not loaded")
        val samplerConfig = SamplerConfig(
            topK = topK,
            topP = topP,
            temperature = temperature.toDouble(),
        )
        val conversationConfig = ConversationConfig(
            samplerConfig = samplerConfig,
            systemInstruction = null,
        )
        val conversation = engine.createConversation(conversationConfig)
        return try {
            val message = Contents.of(Content.Text(prompt))
            val extra = mapOf("enable_thinking" to enableThinking)
            val response = conversation.sendMessage(message, extra)
            val thinking = response.channels["thought"]
            val text = response.toString()
            if (!thinking.isNullOrEmpty()) {
                "<|channel>thought\n$thinking<channel|>$text"
            } else {
                text
            }
        } finally {
            runCatching { conversation.close() }
        }
    }

    private fun mediaPipeGenerate(
        prompt: String,
        temperature: Float,
        topK: Int,
        topP: Double,
        randomSeed: Int,
        enableThinking: Boolean,
    ): String {
        val llm = mediaPipeLlm ?: throw IllegalStateException("MediaPipe LLM not loaded")
        if (enableThinking) {
            Log.w(TAG, "enableThinking ignored for MediaPipe .task path")
        }
        val sessionOptions = LlmInferenceSession.LlmInferenceSessionOptions.builder()
            .setTemperature(temperature)
            .setRandomSeed(randomSeed)
            .setTopK(topK)
            .setTopP(topP.toFloat())
            .build()
        val session = LlmInferenceSession.createFromOptions(llm, sessionOptions)
        return try {
            session.addQueryChunk(prompt)
            session.generateResponse() ?: ""
        } finally {
            runCatching { session.close() }
        }
    }

    private fun generateStream(arguments: Any?, sink: EventChannel.EventSink?) {
        if (sink == null) return
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?> ?: return
        val prompt = args["prompt"] as String
        val temperature = (args["temperature"] as Number).toFloat()
        val topK = (args["topK"] as Number).toInt()
        val topP = (args["topP"] as Number).toDouble()
        val randomSeed = (args["randomSeed"] as Number).toInt()
        val enableThinking = args["enableThinking"] as Boolean
        val path = loadedPath

        val job = ActiveStream()
        try {
            if (path != null && path.endsWith(".litertlm", ignoreCase = true)) {
                activeStream.set(job)
                litertGenerateStream(prompt, temperature, topK, topP, enableThinking, sink, job)
            } else if (mediaPipeLlm != null) {
                activeStream.set(job)
                mediaPipeGenerateStream(
                    prompt,
                    temperature,
                    topK,
                    topP,
                    randomSeed,
                    enableThinking,
                    sink,
                    job,
                )
            } else {
                mainHandler.post {
                    sink.error("stream_failed", "Model not loaded", null)
                }
                return
            }
            if (!job.cancelled) {
                mainHandler.post { sink.endOfStream() }
            }
        } catch (e: Exception) {
            Log.e(TAG, "stream failed", e)
            mainHandler.post { sink.error("stream_failed", e.message, null) }
        } finally {
            activeStream.compareAndSet(job, null)
        }
    }

    private fun litertGenerateStream(
        prompt: String,
        temperature: Float,
        topK: Int,
        topP: Double,
        enableThinking: Boolean,
        sink: EventChannel.EventSink,
        job: ActiveStream,
    ) {
        val engine = liteRtEngine ?: throw IllegalStateException("LiteRT engine not loaded")
        val samplerConfig = SamplerConfig(
            topK = topK,
            topP = topP,
            temperature = temperature.toDouble(),
        )
        val conversationConfig = ConversationConfig(
            samplerConfig = samplerConfig,
            systemInstruction = null,
        )
        val conversation = engine.createConversation(conversationConfig)
        job.liteRtConversation = conversation
        val message = Contents.of(Content.Text(prompt))
        val extra = mapOf("enable_thinking" to enableThinking)
        val done = CountDownLatch(1)
        var streamError: Throwable? = null

        val callback = object : MessageCallback {
            override fun onMessage(msg: Message) {
                if (job.cancelled) return
                val thinking = msg.channels["thought"]
                val text = msg.toString()
                val combined = buildString {
                    if (!thinking.isNullOrEmpty()) {
                        append("<|channel>thought\n$thinking<channel|>")
                    }
                    if (text.isNotEmpty()) append(text)
                }
                if (combined.isNotEmpty()) {
                    mainHandler.post {
                        if (!job.cancelled) sink.success(combined)
                    }
                }
            }

            override fun onDone() {
                done.countDown()
            }

            override fun onError(throwable: Throwable) {
                streamError = throwable
                done.countDown()
            }
        }

        try {
            conversation.sendMessageAsync(message, callback, extra)
            if (!done.await(12, TimeUnit.MINUTES)) {
                throw IllegalStateException("LiteRT stream timed out")
            }
            streamError?.let { throw it }
        } finally {
            runCatching { conversation.close() }
        }
    }

    private fun mediaPipeGenerateStream(
        prompt: String,
        temperature: Float,
        topK: Int,
        topP: Double,
        randomSeed: Int,
        enableThinking: Boolean,
        sink: EventChannel.EventSink,
        job: ActiveStream,
    ) {
        val llm = mediaPipeLlm ?: throw IllegalStateException("MediaPipe LLM not loaded")
        if (enableThinking) {
            Log.w(TAG, "enableThinking ignored for MediaPipe .task path")
        }
        val sessionOptions = LlmInferenceSession.LlmInferenceSessionOptions.builder()
            .setTemperature(temperature)
            .setRandomSeed(randomSeed)
            .setTopK(topK)
            .setTopP(topP.toFloat())
            .build()
        val session = LlmInferenceSession.createFromOptions(llm, sessionOptions)
        job.mpSession = session
        val done = CountDownLatch(1)
        try {
            session.addQueryChunk(prompt)
            session.generateResponseAsync { partial, isDone ->
                if (partial != null && !job.cancelled) {
                    mainHandler.post {
                        if (!job.cancelled) sink.success(partial)
                    }
                }
                if (isDone) {
                    done.countDown()
                }
            }
            if (!done.await(12, TimeUnit.MINUTES)) {
                throw IllegalStateException("MediaPipe stream timed out")
            }
        } finally {
            runCatching { session.close() }
        }
    }
}
