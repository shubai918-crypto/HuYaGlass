import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../modules/home/follow_store.dart';
import '../modules/home/home_page.dart';

const _kTask = 'huyaLiveCheck';
const _kIcon = '@mipmap/ic_launcher';

/// ★ 后台隔离区入口：App 被杀后由 workmanager 唤醒执行
@pragma('vm:entry-point')
void notifyCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await runLiveCheck();
    } catch (_) {}
    return true;
  });
}

/// 轮询订阅列表，发现 未开播→开播 跳变就发系统通知（前台/后台隔离区共用）
Future<String> runLiveCheck() async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('notice_on') ?? false)) return '提醒未开启';

  final fln = FlutterLocalNotificationsPlugin();
  await fln.initialize(const InitializationSettings(
    android: AndroidInitializationSettings(_kIcon),
  ));

  final rooms = (jsonDecode(prefs.getString('notify_rooms') ?? '[]') as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  if (rooms.isEmpty) return '暂无订阅';

  final prev = Map<String, bool>.from(
      jsonDecode(prefs.getString('notify_live_map') ?? '{}'));
  final resolver = HuyaStreamResolver();
  final now = DateTime.now().millisecondsSinceEpoch;
  final lastPost = prefs.getInt('notify_last_post') ?? 0;
  int liveCount = 0, posted = 0;

  for (final r in rooms) {
    final id = '${r['roomId']}';
    try {
      final info =
          await resolver.resolveStream(id).timeout(const Duration(seconds: 6));
      if (info == null) continue;
      final live = info.isLive == true;
      if (live) liveCount++;
      final was = prev[id];
      prev[id] = live;
      if (live && was == false && now - lastPost > 60000) {
        await fln.show(
          1000 + (id.hashCode.abs() % 100000),
          '🔔 ${r['name']} 开播了',
          '点击进入直播间',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'huya_live', '开播提醒',
              channelDescription: '订阅主播开播时通知',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(r),
        );
        posted++;
        await prefs.setInt('notify_last_post', now);
      }
    } catch (_) {}
  }
  await prefs.setString('notify_live_map', jsonEncode(prev));
  return '检测完成：${rooms.length} 个订阅 · $liveCount 个在播 · 新发 $posted 条通知';
}

class NotifyManager extends GetxService {
  static NotifyManager get to => Get.find<NotifyManager>();

  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
  Timer? _fgTimer;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    // ★ 主隔离区初始化：通知点击 → 直达直播间
    await fln.initialize(
      const InitializationSettings(android: AndroidInitializationSettings(_kIcon)),
      onDidReceiveNotificationResponse: (r) {
        try {
          final m = Map<String, dynamic>.from(jsonDecode(r.payload ?? '{}'));
          final id = '${m['roomId'] ?? ''}';
          if (id.isNotEmpty) {
            goLive(id, nickname: '${m['name'] ?? ''}', avatarUrl: '${m['avatar'] ?? ''}');
          }
        } catch (_) {}
      },
    );
    // Android 13+ 通知权限
    await fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    // 后台任务引擎
    Workmanager().initialize(notifyCallbackDispatcher, isInDebugMode: false);
    // 同步一次订阅快照 + 播种基线
    await syncRooms();
    await runLiveCheck();
    // 前台即时检测：每 5 分钟
    _fgTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await syncRooms();
      await runLiveCheck();
    });
  }

  /// 开关：注册/注销 15 分钟后台周期任务
  Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notice_on', on);
    if (on) {
      await syncRooms();
      await Workmanager().registerPeriodicTask(
        _kTask, _kTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      await runLiveCheck();
    } else {
      await Workmanager().cancelByUniqueName(_kTask);
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notice_on') ?? false;
  }

  /// 把当前订阅列表快照到 SharedPreferences，供后台隔离区读取
  Future<void> syncRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = FollowStore.to.items
          .map((e) => {'roomId': e.roomId, 'name': e.name, 'avatar': e.avatar})
          .toList();
      await prefs.setString('notify_rooms', jsonEncode(list));
    } catch (_) {}
  }

  Future<String> checkNow() => runLiveCheck();

  @override
  void onClose() {
    _fgTimer?.cancel();
    super.onClose();
  }
}
