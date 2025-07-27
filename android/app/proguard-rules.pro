# ProGuard rules for MediaPipe, TensorFlow Lite, protobuf, and AutoValue
# MediaPipe Tasks GenAI
-keep class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.tasks.genai.** { *; }
-keep class com.google.mediapipe.tasks.core.** { *; }
-keep class com.google.mediapipe.tasks.components.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-keep class com.google.mediapipe.formats.** { *; }

# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }

# Protocol Buffers
-keep class com.google.protobuf.** { *; }
-keep class com.google.protobuf.nano.** { *; }

# AutoValue (used by MediaPipe)
-keep class com.google.auto.value.** { *; }

# Prevent stripping of native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep annotations
-keep @interface com.google.**

# Keep all public classes and methods in your app package (optional, for debugging)
#-keep class com.example.flutter_gallery.** { *; }

# Added from missing_rules.txt to suppress R8 warnings/errors
-dontwarn com.google.auto.value.AutoValue$Builder
-dontwarn com.google.auto.value.AutoValue
-dontwarn com.google.mediapipe.framework.image.BitmapExtractor
-dontwarn com.google.mediapipe.framework.image.ByteBufferExtractor
-dontwarn com.google.mediapipe.framework.image.MPImage
-dontwarn com.google.mediapipe.framework.image.MPImageProperties
-dontwarn com.google.mediapipe.framework.image.MediaImageExtractor
-dontwarn com.google.protobuf.Internal$ProtoMethodMayReturnNull
-dontwarn com.google.protobuf.Internal$ProtoNonnullApi
-dontwarn com.google.protobuf.ProtoField
-dontwarn com.google.protobuf.ProtoPresenceBits
-dontwarn com.google.protobuf.ProtoPresenceCheckedField
-dontwarn javax.lang.model.element.Modifier
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
