# Google Play Core (optional; Flutter deferred components — not bundled in APK)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MediaPipe (flutter_gemma / LiteRT) — R8 sees optional proto refs not on classpath
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# AGP-generated missing rules (minifyReleaseWithR8)
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# Protocol buffers
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# LiteRT-LM (Gemma .litertlm) — JNI + reflection; mirror flutter_gemma consumer rules
# so release R8 does not strip native stubs (UnsatisfiedLinkError on
# NativeLibraryLoader.nativeCheckLoaded, etc.).
-keep class com.google.ai.edge.litertlm.** { *; }
-keep class com.google.ai.edge.litertlm.NativeLibraryLoader { *; }
-keep class com.google.ai.edge.litertlm.LiteRtLmJni { *; }
-keepclasseswithmembernames,includedescriptorclasses class com.google.ai.edge.litertlm.** {
    native <methods>;
}
-keep class com.google.ai.edge.localagents.** { *; }
-dontwarn com.google.ai.edge.localagents.**
-keepclassmembers class com.google.mediapipe.tasks.genai.llminference.LlmInference { *; }
-keep class com.google.mediapipe.proto.** { *; }

# Guava / coroutines pulled in by LiteRT / MediaPipe
-keep class com.google.common.** { *; }
-dontwarn com.google.common.**
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# HF token from repo-root .env (BuildConfig + MainActivity MethodChannel)
-keep class za.co.ikamvalam.ikamva_lam.BuildConfig { *; }
-keep class za.co.ikamvalam.ikamva_lam.MainActivity { *; }
