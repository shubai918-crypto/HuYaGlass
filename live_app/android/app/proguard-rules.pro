# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-ignorewarnings

# Gson / JSON 序列化（如果你用了）
-keepattributes Signature
-keepattributes *Annotation*

# WebView
-keepclassmembers class fqcn.of.javascript.interface.for.webview {
   public *;
}

# 保留 R 类
-keepclassmembers class **.R$* {
    public static <fields>;
}
