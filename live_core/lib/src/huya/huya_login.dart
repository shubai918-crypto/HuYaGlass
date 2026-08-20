import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 虎牙登录管理（Cookie 持久化，重启不丢）
class HuyaLoginManager {
  static final HuyaLoginManager _instance = HuyaLoginManager._internal();
  factory HuyaLoginManager() => _instance;
  HuyaLoginManager._internal();

  static const _key = 'huya_cookie';
  static bool _loaded = false;

  final instanceVersion = 0.obs;
  String _cookie = '';

  String get cookie => _cookie;
  bool get isLoggedIn => _cookie.isNotEmpty;

  /// App 启动时调用一次，恢复登录态
  static Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _instance._cookie = (prefs.getString(_key) ?? '').trim();
    } catch (_) {}
    _loaded = true;
    _instance.instanceVersion.value++;
  }

  void setCookie(String c) {
    _cookie = c.trim();
    instanceVersion.value++;
    _save();
  }

  void logout() {
    _cookie = '';
    instanceVersion.value++;
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _cookie);
    } catch (_) {}
  }
}
