import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 后台播放：持久化开关 + 电池白名单 + 唤醒锁 + 前台服务
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
    if (v) {
      await requestBatteryWhitelist();
      await startService(); // ★ 开启即挂前台服务，ColorOS 不敢杀
    } else {
      await stopService();
      await releaseWakeLock();
    }
  }

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

  static Future<void> startService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }
}
