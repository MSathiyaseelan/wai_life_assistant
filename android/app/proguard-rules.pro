# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Supabase / Realtime / Ktor / OkHttp
-keep class io.github.jan.supabase.** { *; }
-keepnames class io.ktor.** { *; }
-keepnames class kotlinx.coroutines.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Speech to Text
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Local Auth (biometrics)
-keep class io.flutter.plugins.localauth.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Flutter Contacts
-keep class gh.com.justkawal.contacts.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Quick Actions
-keep class io.flutter.plugins.quickactions.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Device Info Plus / Package Info Plus
-keep class dev.fluttercommunity.plus.** { *; }

# PDF
-keep class com.tom_roush.pdfbox.** { *; }

# Kotlin serialization (used by Supabase/Ktor internally)
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class **$$serializer { *; }

# General — keep model classes from being stripped
-keepattributes Signature
-keepattributes Exceptions
