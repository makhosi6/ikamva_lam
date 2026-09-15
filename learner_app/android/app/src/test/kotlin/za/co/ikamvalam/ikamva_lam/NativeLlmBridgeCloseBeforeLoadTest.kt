package za.co.ikamvalam.ikamva_lam

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Structural unit test verifying that [NativeLlmBridge] calls `closeAllEngines()`
 * as the first statement in `handleLoad` (Requirement 2.2).
 *
 * This test reads the Kotlin source file and verifies the structural invariant:
 * `closeAllEngines()` must appear before any other substantive call inside
 * `handleLoad`. This is a compile-time / source-level guard that catches
 * accidental reordering during future refactors.
 *
 * Requirement 2.2: "WHEN `loadModel` is called and a model is already loaded,
 * THE `NativeLlmBridge` SHALL close the existing runtime before opening the
 * new one."
 */
class NativeLlmBridgeCloseBeforeLoadTest {

    companion object {
        /**
         * Locates the NativeLlmBridge.kt source file relative to the project
         * root. The test is run from the Gradle project directory, so we walk
         * up from the working directory to find the source.
         */
        private fun findSourceFile(): java.io.File {
            val relativePath =
                "app/src/main/kotlin/za/co/ikamvalam/ikamva_lam/NativeLlmBridge.kt"
            // Gradle runs unit tests with cwd = <project>/android
            val fromAndroid = java.io.File(relativePath)
            if (fromAndroid.exists()) return fromAndroid
            // Fallback: search up from cwd
            var dir = java.io.File(System.getProperty("user.dir") ?: ".")
            repeat(5) {
                val candidate = java.io.File(dir, relativePath)
                if (candidate.exists()) return candidate
                dir = dir.parentFile ?: return@repeat
            }
            error("Cannot locate NativeLlmBridge.kt from ${System.getProperty("user.dir")}")
        }
    }

    /**
     * Parses the `handleLoad` function body from the source file and asserts
     * that `closeAllEngines()` is the first non-blank, non-comment statement.
     *
     * This guards against future refactors accidentally moving the close call
     * after the model-open logic.
     */
    @Test
    fun `handleLoad has closeAllEngines as its first statement`() {
        val source = findSourceFile().readText()

        // Extract the body of handleLoad by finding the function declaration
        // and collecting lines until the matching closing brace.
        val handleLoadStart = source.indexOf("private fun handleLoad(")
        assertTrue(
            "handleLoad function not found in NativeLlmBridge.kt",
            handleLoadStart >= 0,
        )

        // Find the opening brace of the function body.
        val openBrace = source.indexOf('{', handleLoadStart)
        assertTrue("handleLoad opening brace not found", openBrace >= 0)

        // Collect lines inside the function body (stop at the matching close brace).
        val bodyLines = mutableListOf<String>()
        var depth = 0
        var i = openBrace
        while (i < source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) break
                }
                '\n' -> {
                    val lineStart = source.lastIndexOf('\n', i - 1).let { if (it < 0) 0 else it + 1 }
                    bodyLines.add(source.substring(lineStart, i).trim())
                }
            }
            i++
        }

        // Find the first non-blank, non-comment line inside the function body.
        val firstStatement = bodyLines
            .drop(1) // skip the opening-brace line itself
            .firstOrNull { line ->
                line.isNotBlank() &&
                    !line.startsWith("//") &&
                    !line.startsWith("/*") &&
                    !line.startsWith("*")
            }

        assertTrue(
            "Expected closeAllEngines() to be the first statement in handleLoad, " +
                "but found: '$firstStatement'",
            firstStatement?.contains("closeAllEngines()") == true,
        )
    }

    /**
     * Verifies that `closeAllEngines` itself nulls out both engine fields and
     * `loadedPath` by inspecting the source body of the function.
     */
    @Test
    fun `closeAllEngines nulls liteRtEngine mediaPipeLlm and loadedPath`() {
        val source = findSourceFile().readText()

        val fnStart = source.indexOf("private fun closeAllEngines()")
        assertTrue("closeAllEngines function not found", fnStart >= 0)

        val openBrace = source.indexOf('{', fnStart)
        // Walk to the matching closing brace (accounting for nested braces).
        var depth = 0
        var closeBrace = openBrace
        for (idx in openBrace until source.length) {
            when (source[idx]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) {
                        closeBrace = idx
                        break
                    }
                }
            }
        }
        val body = source.substring(openBrace, closeBrace + 1)

        assertTrue(
            "closeAllEngines should set liteRtEngine = null",
            body.contains("liteRtEngine = null"),
        )
        assertTrue(
            "closeAllEngines should set mediaPipeLlm = null",
            body.contains("mediaPipeLlm = null"),
        )
        assertTrue(
            "closeAllEngines should set loadedPath = null",
            body.contains("loadedPath = null"),
        )
    }
}
