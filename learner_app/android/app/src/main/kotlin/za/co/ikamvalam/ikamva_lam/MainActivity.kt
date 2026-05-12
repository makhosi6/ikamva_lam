package za.co.ikamvalam.ikamva_lam

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // TextureView (vs the default SurfaceView) keeps Flutter's frames off the
    // SurfaceFlinger BLASTBufferQueue, so native GPU model load / inference
    // cannot starve the UI buffer queue.
    // QUEUE_BUFFER_TIMEOUT / "Already acquired max frames" crashes seen on
    // weaker GPUs (e.g. MediaTek Iris X7) during Gemma 4 warm-up.
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "za.co.ikamvalam/hf_token",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getIkamvaHfToken") {
                result.success(BuildConfig.IKAMVA_HF_TOKEN)
            } else {
                result.notImplemented()
            }
        }
        NativeLlmBridge.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
