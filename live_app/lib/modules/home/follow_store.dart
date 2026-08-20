import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FollowItem {
  final String roomId;
  final String name;
  final String avatar;
  FollowItem({required this.roomId, required this.name, this.avatar = ''});

  Map<String, dynamic> toJson() => {'roomId': roomId, 'name': name, 'avatar': avatar};

  factory FollowItem.fromJson(Map<String, dynamic> j) => FollowItem(
        roomId: '${j['roomId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        avatar: '${j['avatar'] ?? ''}',
      );
}

class FollowStore {
  static const _key = 'huya_follows';

  static Future<List<FollowItem>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => FollowItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isFollowed(String roomId) async {
    final list = await all();
    return list.any((e) => e.roomId == roomId);
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

  static Future<void> _save(List<FollowItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
