package za.co.ikamvalam.ikamva_lam

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Feature: native-inference-engine, Property 3: Sequential loadModel calls close
 * the previous runtime.
 *
 * Structural guard: [NativeLlmBridge.handleLoad] must invoke [closeAllEngines]
 * before any [File] existence check or engine construction (Requirement 2.2).
 */
class NativeLlmBridgeSequentialLoadSourceTest {

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
            error("Cannot locate NativeLlmBridge.kt from ${System.getProperty("user.dir")}")
        }

        private fun handleLoadBody(source: String): String {
            val handleLoadStart = source.indexOf("private fun handleLoad(")
            assertTrue("handleLoad not found", handleLoadStart >= 0)
            val openBrace = source.indexOf('{', handleLoadStart)
            assertTrue("handleLoad brace not found", openBrace >= 0)
            var depth = 0
            var i = openBrace
            while (i < source.length) {
                when (source[i]) {
                    '{' -> depth++
                    '}' -> {
                        depth--
                        if (depth == 0) {
                            return source.substring(openBrace, i + 1)
                        }
                    }
                }
                i++
            }
            error("unbalanced braces in handleLoad")
        }
    }

    @Test
    fun `handleLoad calls closeAllEngines before File path check`() {
        val body = handleLoadBody(findSourceFile().readText())
        val closeIdx = body.indexOf("closeAllEngines()")
        val fileIdx = body.indexOf("File(path)")
        assertTrue("closeAllEngines() missing from handleLoad", closeIdx >= 0)
        assertTrue("File(path) missing from handleLoad", fileIdx >= 0)
        assertTrue(
            "closeAllEngines() must precede File(path) in handleLoad",
            closeIdx < fileIdx,
        )
    }

    @Test
    fun `handleLoad calls closeAllEngines before Engine or LlmInference construction`() {
        val body = handleLoadBody(findSourceFile().readText())
        val closeIdx = body.indexOf("closeAllEngines()")
        val engineIdx = body.indexOf("Engine(cfg)")
        val mpIdx = body.indexOf("LlmInference.createFromOptions")
        assertTrue(closeIdx >= 0)
        if (engineIdx >= 0) {
            assertTrue("closeAllEngines before Engine(cfg)", closeIdx < engineIdx)
        }
        if (mpIdx >= 0) {
            assertTrue("closeAllEngines before LlmInference.createFromOptions", closeIdx < mpIdx)
        }
    }
}
