import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:live_core/live_core.dart';
import '../../common/services/login_service.dart';

class FollowController extends GetxController {
  final followedList = <LiveRoom>[].obs;
  final loading = false.obs;
  final loginService = Get.find<LoginService>();

  late Box _localFollowBox;
  HuyaFollowService? _followService;

  @override
  void onInit() {
    super.onInit();
    _localFollowBox = Hive.box('follow');
    _loadLocalFollows();
    // 如果已登录，同步线上订阅列表
    if (loginService.isLoggedIn.value) {
      _syncOnlineFollows();
    }
  }

  void _loadLocalFollows() {
    final list = _localFollowBox.values.toList();
    followedList.assignAll(
      list.map((e) => LiveRoom.fromJson(Map<String, dynamic>.from(e as Map))),
    );
    _sortByLiveStatus();
  }

  Future<void> _syncOnlineFollows() async {
    if (!loginService.isLoggedIn.value) return;
    _followService = HuyaFollowService(cookie: loginService.cookie.value);
    loading.value = true;

    try {
      final onlineList = await _followService!.getSubscribedList();
      // 合并线上和本地
      for (var room in onlineList) {
        if (!followedList.any((r) => r.presenterUid == room.presenterUid)) {
          followedList.add(room);
          _localFollowBox.put(room.roomId, room.toJson());
        }
      }
      _sortByLiveStatus();
    } catch (e) {
      // 网络错误，使用本地缓存
    } finally {
      loading.value = false;
    }
  }

  /// 直播中的排前面（参考 dtv_mobile FollowScreen）
  void _sortByLiveStatus() {
    final live = followedList.where((r) => r.isLive).toList();
    final offline = followedList.where((r) => !r.isLive).toList();
    followedList.assignAll([...live, ...offline]);
  }

  /// 添加关注
  Future<void> addFollow(LiveRoom room) async {
    // 本地保存
    _localFollowBox.put(room.roomId, room.toJson());
    if (!followedList.any((r) => r.roomId == room.roomId)) {
      followedList.add(room);
      _sortByLiveStatus();
    }

    // 线上订阅
    if (loginService.isLoggedIn.value && room.presenterUid > 0) {
      _followService ??= HuyaFollowService(cookie: loginService.cookie.value);
      await _followService!.subscribe(presenterUid: room.presenterUid, source: 'app');
    }
  }

  /// 取消关注
  Future<void> removeFollow(LiveRoom room) async {
    _localFollowBox.delete(room.roomId);
    followedList.removeWhere((r) => r.roomId == room.roomId);

    if (loginService.isLoggedIn.value && room.presenterUid > 0) {
      _followService ??= HuyaFollowService(cookie: loginService.cookie.value);
      await _followService!.unsubscribe(presenterUid: room.presenterUid);
    }
  }

  /// 检查是否已关注
  bool isFollowed(String roomId) {
    return followedList.any((r) => r.roomId == roomId);
  }

  bool isFollowedByUid(int uid) {
    return followedList.any((r) => r.presenterUid == uid);
  }

  /// 刷新列表
  Future<void> refresh() async {
    loading.value = true;
    await _syncOnlineFollows();
    loading.value = false;
  }
}
