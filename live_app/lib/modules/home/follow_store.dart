import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FollowItem {
  final String roomId;
  final String name;
  final String avatar;
  final bool isLive;
  const FollowItem({
    required this.roomId,
    required this.name,
    this.avatar = '',
    this.isLive = false,
  });

  FollowItem copyWith({String? name, String? avatar, bool? isLive}) =>
      FollowItem(
        roomId: roomId,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        isLive: isLive ?? this.isLive,
      );

  Map<String, dynamic> toJson() =>
      {'roomId': roomId, 'name': name, 'avatar': avatar, 'isLive': isLive};

  static FollowItem fromJson(Map<String, dynamic> j) => FollowItem(
        roomId: '${j['roomId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        avatar: '${j['avatar'] ?? ''}',
        isLive: j['isLive'] == true,
      );
}

/// ★ 响应式订阅仓库：add/remove 立即通知 UI，无需重启
class FollowStore {
  FollowStore._();
  static final FollowStore _i = FollowStore._();
  static FollowStore get instance => _i;

  static const _key = 'follow_list_v1';

  final RxList<FollowItem> items = <FollowItem>[].obs;
  final RxBool refreshing = false.obs;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '';
    if (raw.isEmpty) return;
    try {
      final arr = jsonDecode(raw) as List;
      _i.items.assignAll(arr
          .whereType<Map<String, dynamic>>()
          .map((e) => FollowItem.fromJson(e)));
    } catch (_) {}
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_i.items.map((e) => e.toJson()).toList()));
  }

  static bool isFollowed(String roomId) =>
      _i.items.any((e) => e.roomId == roomId);

  static void add(FollowItem item) {
    if (isFollowed(item.roomId)) return;
    _i.items.add(item);
    _save();
  }

  static void remove(String roomId) {
    _i.items.removeWhere((e) => e.roomId == roomId);
    _save();
  }

  static void updateLive(String roomId, bool isLive,
      {String? name, String? avatar}) {
    final idx = _i.items.indexWhere((e) => e.roomId == roomId);
    if (idx < 0) return;
    _i.items[idx] = _i.items[idx].copyWith(
      isLive: isLive,
      name: name,
      avatar: avatar,
    );
  }
}
