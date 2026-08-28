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
    // 这里可以接入真实的网络请求或本地数据库读取
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
