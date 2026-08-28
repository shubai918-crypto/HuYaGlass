import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FollowItem {
  final String roomId;
  final String name;
  final String avatar;
  final bool isLive;

  FollowItem({
    required this.roomId,
    required this.name,
    this.avatar = '',
    this.isLive = false,
  });

  Map<String, dynamic> toJson() =>
      {'roomId': roomId, 'name': name, 'avatar': avatar, 'isLive': isLive};

  static FollowItem fromJson(Map<String, dynamic> j) => FollowItem(
        roomId: '${j['roomId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        avatar: '${j['avatar'] ?? ''}',
        isLive: j['isLive'] == true,
      );
}

class FollowStore extends GetxController {
  static FollowStore get to => Get.find<FollowStore>();
  static const _key = 'huya_follow_list_v1';

  final items = <FollowItem>[].obs;
  final refreshing = false.obs;

  static Future<void> init() async {
    if (!Get.isRegistered<FollowStore>()) Get.put(FollowStore());
    await to._load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key) ?? '';
      if (raw.isEmpty) return;
      final arr = jsonDecode(raw) as List;
      items.assignAll(arr
          .whereType<Map<String, dynamic>>()
          .map((e) => FollowItem.fromJson(e))
          .toList());
    } catch (_) {}
  }

  // ★ 修复：去掉下划线，改为公开方法，允许跨文件调用
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static bool contains(String roomId) =>
      to.items.any((e) => e.roomId == roomId);

  static Future<bool> isFollowed(String roomId) async => contains(roomId);

  static Future<void> add(FollowItem item) async {
    final store = to;
    if (store.items.any((e) => e.roomId == item.roomId)) return;
    store.items.add(item);
    await store.save(); // 内部调用也同步修改
  }

  static Future<void> remove(String roomId) async {
    final store = to;
    store.items.removeWhere((e) => e.roomId == roomId);
    await store.save(); // 内部调用也同步修改
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
