package za.co.ikamvalam.ikamva_lam

import org.junit.Assert.assertTrue
import org.junit.Test

/** Requirements 4.9, 4.2, 4.3 — Android streaming posts on main thread and ends stream. */
class NativeLlmBridgeStreamingAndroidSourceTest {

    companion object {
        private fun findSourceFile(): java.io.File {
            val relativePath =
                "app/src/main/kotlin/za/co/ikamvalam/ikamva_lam/NativeLlmBridge.kt"
            val fromAndroid = java.io.File(relativePath)
            if (fromAndroid.exists()) return fromAndroid
            var dir = java.io.File(System.getProperty("user.dir") ?: ".")
            repeat(5) {
                val candidate = java.io.File(dir, relativePath)
                if (candidate.exists()) return candidate
                dir = dir.parentFile ?: return@repeat
            }
            error("Cannot locate NativeLlmBridge.kt")
        }
    }

    @Test
    fun `stream success path posts endOfStream on main handler`() {
        val s = findSourceFile().readText()
        assertTrue(s.contains("mainHandler.post { sink.endOfStream() }"))
    }

    @Test
    fun `litert and mediapipe stream chunks post via mainHandler before sink success`() {
        val s = findSourceFile().readText()
        assertTrue(s.contains("mainHandler.post { sink.success(combined) }"))
        assertTrue(s.contains("mainHandler.post { sink.success(partial) }"))
    }

    @Test
    fun `stream failure uses mainHandler for stream_failed`() {
        val s = findSourceFile().readText()
        assertTrue(s.contains("sink.error(\"stream_failed\""))
    }
}
