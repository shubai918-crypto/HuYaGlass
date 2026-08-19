import 'package:get/get.dart';

class HuyaLoginManager {
  static final HuyaLoginManager _instance = HuyaLoginManager._internal();
  factory HuyaLoginManager() => _instance;
  HuyaLoginManager._internal();

  final instanceVersion = 0.obs;
  String _cookie = '';

  String get cookie => _cookie;
  bool get isLoggedIn => _cookie.isNotEmpty;

  void setCookie(String c) {
    _cookie = c.trim();
    instanceVersion.value++;
  }

  void logout() {
    _cookie = '';
    instanceVersion.value++;
  }
}
