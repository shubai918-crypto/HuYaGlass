import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final String roomId;
  final String name;
  final String avatar;
  final int ts;
  HistoryItem({required this.roomId, required this.name, this.avatar = '', required this.ts});
  Map<String, dynamic> toJson() => {'roomId': roomId, 'name': name, 'avatar': avatar, 'ts': ts};
  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
      roomId: '${j['roomId'] ?? ''}', name: '${j['name'] ?? ''}',
      avatar: '${j['avatar'] ?? ''}', ts: (j['ts'] as num?)?.toInt() ?? 0);
}

class HistoryStore {
  static final RxList<HistoryItem> items = <HistoryItem>[].obs;
  static const _key = 'huya_history';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key) ?? '[]';
      final list = (jsonDecode(raw) as List)
          .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      items.assignAll(list);
    } catch (_) {}
  }

  static Future<void> add(String roomId, String name, String avatar) async {
    if (roomId.isEmpty) return;
    items.removeWhere((e) => e.roomId == roomId);
    items.insert(0, HistoryItem(roomId: roomId, name: name, avatar: avatar, ts: DateTime.now().millisecondsSinceEpoch));
    if (items.length > 50) items.removeRange(50, items.length);
    await _save();
  }

  static Future<void> remove(String roomId) async {
    items.removeWhere((e) => e.roomId == roomId);
    await _save();
  }

  static Future<void> clear() async {
    items.clear();
    await _save();
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}
