import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSettings extends GetxService {
  static AppSettings get to => Get.find<AppSettings>();

  final themeMode = ThemeMode.dark.obs;
  final debugEnabled = false.obs;

  bool get isDark => themeMode.value != ThemeMode.light;
  void toggleTheme() =>
      themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  void setDebug(bool v) => debugEnabled.value = v;
}
