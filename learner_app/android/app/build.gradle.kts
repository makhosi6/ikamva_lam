import org.gradle.api.GradleException
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val ikamvaRepoRootEnv: File =
    rootProject.projectDir.resolve("../../.env").normalize()

/** Must match `flutter_gemma` android `litertlm-android` (pub 0.13.6 → 0.10.0). */
val litertlmAndroidVersion = "0.10.0"

fun readIkamvaHfTokenFromEnvFile(envFile: File): String {
    if (!envFile.isFile) return ""
    var token = ""
    envFile.useLines { lines ->
        for (raw in lines) {
            val line = raw.trim()
            if (line.isEmpty() || line.startsWith("#")) continue
            if (line.startsWith("IKAMVA_HF_TOKEN=")) {
                var v = line.removePrefix("IKAMVA_HF_TOKEN=").trim()
                if (v.length >= 2 &&
                    ((v.startsWith("\"") && v.endsWith("\"")) ||
                        (v.startsWith("'") && v.endsWith("'")))
                ) {
                    v = v.substring(1, v.length - 1).trim()
                }
                token = v
                return@useLines
            }
        }
    }
    return token
}

android {
    namespace = "za.co.ikamvalam.ikamva_lam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Unpacked from `litertlmUnpack` task (see below). Ensures liblitertlm_jni.so is merged
    // even when the AAR arrives only transitively through the Flutter plugin.
    sourceSets.named("main").configure {
        jniLibs.srcDir(layout.buildDirectory.dir("litertlm-jni-extracted/jni"))
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/projects/application-id.html).
        applicationId = "za.co.ikamvalam.ikamva_lam"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val ikamvaHfFromEnv = readIkamvaHfTokenFromEnvFile(ikamvaRepoRootEnv)
   
        val escaped =
            ikamvaHfFromEnv.replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "IKAMVA_HF_TOKEN", "\"$escaped\"")
    }

    // LiteRT-LM JNI: install-time extract can fix load failures on some OEMs / AGP paths.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts += "**/liblitertlm_jni.so"
        }
    }

    androidResources {
        noCompress += listOf("tflite", "litertlm", "task", "bin", "model")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

// Resolved only to unpack JNI; Java API comes from explicit `litertlm-android` below.
val litertlmUnpack =
    configurations.create("litertlmUnpack") {
        isCanBeResolved = true
        isCanBeConsumed = false
    }
dependencies {
    "litertlmUnpack"("com.google.ai.edge.litertlm:litertlm-android:$litertlmAndroidVersion") {
        isTransitive = false
    }
    implementation("com.google.mediapipe:tasks-genai:0.10.33")
    implementation("com.google.ai.edge.litertlm:litertlm-android:$litertlmAndroidVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

val extractLiteRtJniLibs =
    tasks.register<Sync>("extractLiteRtJniLibs") {
        group = "build"
        description =
            "Unpacks litertlm-android JNI into build/ so app jniLibs merge always includes it."
        val aar =
            litertlmUnpack.files.singleOrNull { it.name.startsWith("litertlm-android") }
                ?: error(
                    "litertlmUnpack: expected one litertlm-android aar, got: " +
                        litertlmUnpack.files.joinToString { it.name },
                )
        from(zipTree(aar)) {
            include("jni/**")
        }
        into(layout.buildDirectory.dir("litertlm-jni-extracted"))
    }

tasks.named("preBuild").configure { dependsOn(extractLiteRtJniLibs) }

val verifyIkamvaHfTokenInEnv by tasks.registering {
    group = "verification"
    description =
        "Fails release builds if repo-root .env is missing or IKAMVA_HF_TOKEN is empty."
    doLast {
        if (!ikamvaRepoRootEnv.isFile) {
            throw GradleException(
                "Release build requires repo-root .env at ${ikamvaRepoRootEnv.absolutePath} " +
                    "with a non-empty IKAMVA_HF_TOKEN.",
            )
        }
        val token = readIkamvaHfTokenFromEnvFile(ikamvaRepoRootEnv)
        if (token.isBlank()) {
            throw GradleException(
                "Release build requires non-empty IKAMVA_HF_TOKEN in ${ikamvaRepoRootEnv.absolutePath}. " +
                    "Example: IKAMVA_HF_TOKEN=hf_…",
            )
        }
    }
}

afterEvaluate {
    tasks.named("preReleaseBuild").configure {
        dependsOn(verifyIkamvaHfTokenInEnv)
    }
}
