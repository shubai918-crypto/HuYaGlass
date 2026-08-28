import 'package:get/get.dart';

class FollowItem {
  final String roomId;
  final String name;
  final String avatar;
  FollowItem({required this.roomId, required this.name, this.avatar = ''});
}

class FollowStore extends GetxController {
  static FollowStore get to => Get.find();

  final items = <FollowItem>[].obs;
  final refreshing = false.obs;

  /// ★ 适配 main.dart 中的 await FollowStore.init();
  static Future<void> init() async {
    if (!Get.isRegistered<FollowStore>()) {
      Get.put(FollowStore());
    }
    // 这里可以加入本地数据库 (如 sqflite / shared_preferences) 的读取逻辑
  }

  static bool contains(String roomId) {
    try {
      return Get.find<FollowStore>().items.any((e) => e.roomId == roomId);
    } catch (_) {
      return false;
    }
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
    // 模拟网络请求或本地读取
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
