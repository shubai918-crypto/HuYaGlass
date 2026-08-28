import 'package:get/get.dart';

class FollowItem {
  final String roomId;
  final String name;
  final String avatar;
  final bool isLive; // ★ 补齐 isLive 字段，适配 Controller 传参

  FollowItem({
    required this.roomId,
    required this.name,
    this.avatar = '',
    this.isLive = false,
  });
}

class FollowStore extends GetxController {
  static FollowStore get to => Get.find();

  final items = <FollowItem>[].obs;
  final refreshing = false.obs;

  /// 适配 main.dart 中的 await FollowStore.init();
  static Future<void> init() async {
    if (!Get.isRegistered<FollowStore>()) {
      Get.put(FollowStore());
    }
  }

  static bool contains(String roomId) {
    try {
      return Get.find<FollowStore>().items.any((e) => e.roomId == roomId);
    } catch (_) {
      return false;
    }
  }

  /// ★ 补齐 isFollowed 方法，适配 live_play_controller.dart 的调用
  static Future<bool> isFollowed(String roomId) async {
    return contains(roomId);
  }

  static Future<void> add(FollowItem item) async {
    final store = Get.find<FollowStore>();
    if (!store.items.any((e) => e.roomId == item.roomId)) {
      store.items.add(item);
    }
  }

  static Future<void> remove(String roomId) async {
    final store = Get.find<FollowStore>();
    store.items.removeWhere((e) => e.roomId == roomId);
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
