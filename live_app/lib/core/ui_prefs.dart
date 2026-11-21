import 'package:get/get.dart';

/// 全局 UI 偏好：minimal 省电玻璃材质开关
class UiPrefs extends GetxService {
  static UiPrefs get to => Get.find();
  final minimalGlass = false.obs;
  void setMinimal(bool v) => minimalGlass.value = v;
}
