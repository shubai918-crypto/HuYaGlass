import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 订阅主播条目
class FollowItem {
  final String roomId;
  final String name;
  final String avatar;

  const FollowItem({
    required this.roomId,
    required this.name,
    this.avatar = '',
  });

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'name': name,
        'avatar': avatar,
      };

  static FollowItem fromJson(Map<String, dynamic> j) => FollowItem(
        roomId: '${j['roomId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        avatar: '${j['avatar'] ?? ''}',
      );
}

/// 订阅数据持久化（SharedPreferences + JSON）
class FollowStore {
  static const _key = 'huya_follows';

  static Future<List<FollowItem>> all() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => FollowItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(FollowItem item) async {
    final list = await all();
    list.removeWhere((e) => e.roomId == item.roomId);
    list.insert(0, item);
    await _save(list);
  }

  static Future<void> remove(String roomId) async {
    final list = await all();
    list.removeWhere((e) => e.roomId == roomId);
    await _save(list);
  }

  static Future<bool> contains(String roomId) async {
    final list = await all();
    return list.any((e) => e.roomId == roomId);
  }

  // ★ 新增：兼容播放页控制器的调用
  static Future<bool> isFollowed(String roomId) => contains(roomId);

  static Future<void> _save(List<FollowItem> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
