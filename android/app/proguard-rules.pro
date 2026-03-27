# Flutter standard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# LiteRT / MediaPipe (used by flutter_gemma)
-keep class com.google.mediapipe.** { *; }
-keep class com.google.tensorflow.lite.** { *; }

# flutter_gemma specific (if any)
-keep class com.flutter_gemma.** { *; }

# Support libraries
-keep class androidx.core.** { *; }

# Fix R8 missing classes for Play Core and MediaPipe
-dontwarn com.google.android.play.core.**
-dontwarn com.google.mediapipe.proto.**
