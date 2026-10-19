# 如果以后开启 R8，保留 Flutter 插件与 Pigeon 生成类，避免反射/生成方法被裁掉。
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
