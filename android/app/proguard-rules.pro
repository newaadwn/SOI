# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.firebase.** { *; }
-keep class org.apache.** { *; }
-keepnames class com.fasterxml.jackson.** { *; }
-keepnames class javax.servlet.** { *; }
-keepnames class org.ietf.jgss.** { *; }
-dontwarn org.w3c.dom.**
-dontwarn org.joda.time.**
-dontwarn org.shaded.apache.**
-dontwarn org.ietf.jgss.**

# AudioPlayer 관련
-keep class androidx.lifecycle.** { *; }
-keep class androidx.core.app.** { *; }
-dontwarn androidx.lifecycle.**

# 이미지 관련
-keep class androidx.exifinterface.** { *; }
-dontwarn androidx.exifinterface.**

# Kotlin 관련
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep public class kotlin.reflect.jvm.internal.impl.** { public *; }
-dontwarn kotlin.**

# Retrofit, OkHttp 관련
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# 기타 일반적인 안드로이드 규칙
-keepattributes Exceptions, Signature, InnerClasses, SourceFile, LineNumberTable 