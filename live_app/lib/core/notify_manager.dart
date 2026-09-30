import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modules/home/follow_store.dart';
import '../modules/home/home_page.dart';

class LiveNotifyManager extends GetxService {
  static LiveNotifyManager get to => Get.find<LiveNotifyManager>();

  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    // 1. 初始化通知插件
    await fln.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
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
    // 2. 请求权限 (Android 13+)
    await fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 3. 启动时同步一次订阅 + 播种基线（防止刚开 App 就误报"开播了"）
    await syncRooms();
    await runLiveCheck();

    // 4. 前台/后台保活期间：每 5 分钟检测一次
    _timer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await syncRooms();
      await runLiveCheck();
    });
  }

  /// 开关：控制是否发送通知
  Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notice_on', on);
    if (on) {
      await syncRooms();
      await runLiveCheck();
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notice_on') ?? false;
  }

  /// 同步订阅列表到本地，供检测逻辑读取
  Future<void> syncRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = FollowStore.to.items
          .map((e) => {'roomId': e.roomId, 'name': e.name, 'avatar': e.avatar})
          .toList();
      await prefs.setString('notify_rooms', jsonEncode(list));
    } catch (_) {}
  }

  /// 核心检测逻辑：对比 上次状态 vs 当前状态，发现 未播->在播 就发通知
  Future<String> runLiveCheck() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notice_on') ?? false)) return '提醒未开启';

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
        final info = await resolver.resolveStream(id).timeout(const Duration(seconds: 6));
        if (info == null) continue;
        final live = info.isLive == true;
        if (live) liveCount++;
        
        final was = prev[id];
        prev[id] = live;
        
        // 核心判断：现在是直播(true) && 上次不是直播(false) && 距离上次发通知>1分钟(防抖)
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

  Future<String> checkNow() => runLiveCheck();

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
