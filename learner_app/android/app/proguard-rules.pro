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
