import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 后台播放开关（全局持久化 + 原生唤醒锁/电池白名单）
class BackgroundPlayStore {
  static const _key = 'huya_background_play';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static const _channel = MethodChannel('com.huyalive/background');

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    enabled.value = sp.getBool(_key) ?? false;
  }

  static Future<void> set(bool v) async {
    enabled.value = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, v);
    if (v) await requestBatteryWhitelist();
  }

  /// ★ MIUI/HyperOS 必须忽略电池优化，否则后台必被杀
  static Future<void> requestBatteryWhitelist() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('battery whitelist: $e');
    }
  }

  static Future<void> acquireWakeLock() async {
    try {
      await _channel.invokeMethod('acquireWakeLock');
    } catch (_) {}
  }

  static Future<void> releaseWakeLock() async {
    try {
      await _channel.invokeMethod('releaseWakeLock');
    } catch (_) {}
  }
}
