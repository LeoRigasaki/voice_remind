# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Local Notifications Plugin Rules
-keep class com.dexterous.** { *; }

## GSON Rules (Required for flutter_local_notifications)
# Gson uses generic type information stored in a class file when working with fields. 
# Proguard removes such information by default, so configure it to keep all of it.
-keepattributes Signature

# For using GSON @Expose annotation
-keepattributes *Annotation*

# Gson specific classes
-keep class sun.misc.Unsafe { *; }

# Keep generic signature of TypeToken and its subclasses with generic type parameter
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep generic signature of TypeAdapterFactory implementations and TypeAdapter implementations
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# R8 full mode compatibility (AGP 8.0+)
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# Keep attributes required for reflection
-keepattributes InnerClasses

# Additional safety rules for notifications
-dontwarn sun.misc.**

# Keep notification-related resources
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Flutter Play Store / Google Play Core related rules
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Handle missing Play Core classes gracefully
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Flutter specific rules for deferred components
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Additional Flutter rules
-keep class io.flutter.embedding.android.** { *; }
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# General ignore warnings for missing optional dependencies
-dontwarn java.lang.instrument.ClassFileTransformer
-dontwarn sun.misc.SignalHandler