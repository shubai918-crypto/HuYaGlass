import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 后台播放：媒体前台服务（PiliPlus 同款，无需任何权限弹窗）
class BackgroundPlayStore {
  static const _key = 'huya_background_play';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static const _channel = MethodChannel('com.huyalive/background');

  /// 通知栏媒体按钮回调（控制器注册）
  static void Function(String action)? onMediaAction;

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    enabled.value = sp.getBool(_key) ?? false;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pause':
          onMediaAction?.call('pause');
          return true;
        case 'play':
          onMediaAction?.call('play');
          return true;
        case 'stop':
          onMediaAction?.call('stop');
          return true;
      }
      return false;
    });
  }

  static Future<void> set(bool v) async {
    enabled.value = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, v);
    if (v) {
      await startService();
    } else {
      await stopService();
    }
  }

  /// 同步通知栏播放/暂停状态
  static Future<void> setPlaying(bool playing) async {
    try {
      await _channel.invokeMethod('setPlaying', playing);
    } catch (_) {}
  }

  static Future<bool> startService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
      return true;
    } catch (e) {
      debugPrint('[BG] startService 失败: $e');
      return false;
    }
  }

  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  /// 手动入口（仅设置页按钮调用，不再自动弹）
  static Future<void> requestBatteryWhitelist() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
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
