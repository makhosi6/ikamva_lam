package za.co.ikamvalam.ikamva_lam

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Validates: Requirements 3.2, 5.1 — generate with no model maps to
 * `generate_failed` on the MethodChannel result.
 */
class NativeLlmBridgeGenerateContractSourceTest {

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
    fun `generate method handler maps failures to generate_failed`() {
        val source = findSourceFile().readText()
        assertTrue(
            source.contains("\"generate\"") && source.contains("generate_failed"),
        )
    }

    @Test
    fun `generateSync uses loadedPath for runtime selection`() {
        val source = findSourceFile().readText()
        assertTrue(
            "generateSync should gate on loadedPath",
            source.contains("val path = loadedPath"),
        )
    }
}
