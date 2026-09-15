package za.co.ikamvalam.ikamva_lam

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Requirement 11.3: inference dependencies must not pull in Play Services APIs.
 *
 * Source-level guard on [build.gradle.kts]: explicit `litertlm` / `tasks-genai`
 * coordinates and no `com.google.android.gms` in that file.
 */
class NativeLlmInferenceDependenciesGmsFreeSourceTest {

    companion object {
        private fun findGradleFile(): java.io.File {
            val relativePath = "app/build.gradle.kts"
            val fromAndroid = java.io.File(relativePath)
            if (fromAndroid.exists()) return fromAndroid
            var dir = java.io.File(System.getProperty("user.dir") ?: ".")
            repeat(6) {
                val candidate = java.io.File(dir, relativePath)
                if (candidate.exists()) return candidate
                dir = dir.parentFile ?: return@repeat
            }
            error("Cannot locate app/build.gradle.kts")
        }
    }

    @Test
    fun `build gradle lists litertlm and tasks genai without gms coordinate`() {
        val text = findGradleFile().readText()
        assertTrue(text.contains("litertlm-android"))
        assertTrue(text.contains("tasks-genai"))
        assertFalse(
            "build.gradle.kts should not reference com.google.android.gms for inference",
            text.contains("com.google.android.gms"),
        )
    }
}
