# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Prevent R8 from stripping reflection-based code
-dontwarn com.google.**
-dontwarn io.flutter.**

# Apache Tika / javax.xml.stream — pulled in transitively,
# not available on Android but never called at runtime.
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**
