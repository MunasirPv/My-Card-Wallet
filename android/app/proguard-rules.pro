# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Riverpod
-keep class com.riverpod.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# local_auth
-keep class io.flutter.plugins.localauth.** { *; }

# google_mlkit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.common.**
-dontwarn com.google.mlkit.vision.text.**

# Play Core (Referenced by Flutter for deferred components)
-dontwarn com.google.android.play.core.**

# Prevent stripping encryption classes
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-keep class com.pointycastle.** { *; }

# Remove debug log calls in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
