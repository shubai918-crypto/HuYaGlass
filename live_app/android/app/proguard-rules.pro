# ========== Flutter 核心 ==========
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ========== 网络库（Ktor / OkHttp） ==========
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# ========== WebSocket ==========
-keep class org.java_websocket.** { *; }

# ========== WebView ==========
-keepclassmembers class fqcn.of.javascript.interface.for.webview {
   public *;
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ========== Gson / JSON ==========
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses,EnclosingMethod

# ========== 保留 R 类 ==========
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ========== 保留 Parcelable ==========
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ========== 保留 Serializable ==========
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ========== 保留枚举 ==========
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ========== 忽略警告 ==========
-dontwarn java.lang.invoke.**
-dontwarn sun.misc.Unsafe
-dontwarn kotlin.**
-dontwarn kotlinx.**
-ignorewarnings
