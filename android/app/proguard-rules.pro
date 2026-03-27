# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
# Play Core split-compat referenced by Flutter — not present in non-Play builds
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication

# ── Kotlin ───────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }
-keepclassmembers class kotlin.Metadata { public <methods>; }

# ── media_kit (libmpv JNI bridge) ─────────────────────────────────────────────
-keep class com.alexmercerind.media_kit.** { *; }
-dontwarn com.alexmercerind.media_kit.**

# ── flutter_secure_storage (Android Keystore) ────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keepclassmembers class com.it_nomads.fluttersecurestorage.** { *; }

# ── sqflite (JNI + SQLite) ────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ── dio / OkHttp ─────────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── cached_network_image / Glide ─────────────────────────────────────────────
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class * extends com.bumptech.glide.module.AppGlideModule { <init>(...); }
-keep public enum com.bumptech.glide.load.ImageHeaderParser$** {
    **[] $VALUES;
    public *;
}
-dontwarn com.bumptech.glide.**

# ── device_info_plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# ── url_launcher ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ── General: keep native method names ────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Prevent stripping enums ───────────────────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Serialization safety ─────────────────────────────────────────────────────
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
