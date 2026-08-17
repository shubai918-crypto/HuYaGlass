import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:live_core/live_core.dart';

class FollowController extends GetxController {
  final followedList = <LiveRoom>[].obs;
  final loading = false.obs;

  late Box _followBox;

  @override
  void onInit() {
    super.onInit();
    _followBox = Hive.box('follow');
    _loadFollows();
  }

  void _loadFollows() {
    final list = _followBox.values.toList();
    followedList.assignAll(
      list.map((e) => LiveRoom.fromJson(Map<String, dynamic>.from(e as Map))),
    );
  }

  void addFollow(LiveRoom room) {
    _followBox.put(room.roomId, room.toJson());
    followedList.add(room);
  }

  void removeFollow(String roomId) {
    _followBox.delete(roomId);
    followedList.removeWhere((r) => r.roomId == roomId);
  }

  bool isFollowed(String roomId) {
    return followedList.any((r) => r.roomId == roomId);
  }

  Future<void> refresh() async {
    loading.value = true;
    // TODO: 批量刷新直播间状态
    loading.value = false;
  }
}
