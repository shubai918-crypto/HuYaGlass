import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:video_player/video_player.dart';

class LivePlayController extends GetxController {
  final roomId = Get.parameters['roomId'] ?? '';
  final presenterUid = int.tryParse(Get.parameters['uid'] ?? '0') ?? 0;

  // 状态
  final loading = true.obs;
  final isLive = false.obs;
  final streamerName = ''.obs;
  final streamerAvatar = ''.obs;
  final fansCount = 0.obs;
  final isFollowed = false.obs;
  final showDanmaku = true.obs;
  final danmakuFontSize = 14.0.obs;
  final currentQuality = ''.obs;

  // 数据
  final qualities = <StreamQuality>[].obs;
  Stream<DanmakuMessage>? danmakuStream;

  // 控制器
  VideoPlayerController? _videoController;
  HuyaDanmakuClient? _danmakuClient;
  final inputController = TextEditingController();
  final HuyaStreamResolver _streamResolver = HuyaStreamResolver();
  final HuyaApi _api = HuyaApi();
  final HuyaLoginManager _loginManager = HuyaLoginManager();

  @override
  void onInit() {
    super.onInit();
    _loadStream();
  }

  Future<void> _loadStream() async {
    try {
      final info = await _streamResolver.resolveStream(roomId);
      if (info == null) {
        Get.snackbar('错误', '无法获取直播流', snackPosition: SnackPosition.TOP);
        loading.value = false;
        return;
      }

      streamerName.value = info.streamerInfo.nickname;
      streamerAvatar.value = info.streamerInfo.avatar;
      fansCount.value = info.streamerInfo.fansCount;
      isLive.value = info.isLive;
      qualities.assignAll(info.qualities);

      if (qualities.isNotEmpty) {
        currentQuality.value = qualities.first.name;
        await _playStream(qualities.first);
      }

      // 连接弹幕
      if (isLive.value) {
        _connectDanmaku(info.presenterUid);
      }

      loading.value = false;
    } catch (e) {
      loading.value = false;
      Get.snackbar('错误', '加载失败: $e');
    }
  }

  Future<void> _playStream(StreamQuality quality) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(quality.flvUrl),
    );
    await _videoController!.initialize();
    await _videoController!.play();
    update();
  }

  void _connectDanmaku(int presenterUid) {
    _danmakuClient = HuyaDanmakuClient(_loginManager);
    _danmakuClient!.connect(
      roomId: roomId,
      presenterUid: presenterUid,
    );
    danmakuStream = _danmakuClient!.danmakuStream;
  }

  void switchQuality(StreamQuality quality) {
    currentQuality.value = quality.name;
    _playStream(quality);
  }

  void sendDanmaku(String text) {
    if (text.isEmpty) return;
    if (!_loginManager.isLoggedIn) {
      Get.snackbar('提示', '发送弹幕需要先登录');
      return;
    }
    _danmakuClient?.sendDanmaku(text);
    inputController.clear();
  }

  void toggleFollow() {
    if (!_loginManager.isLoggedIn) {
      Get.snackbar('提示', '订阅需要先登录');
      return;
    }
    // TODO: 调用 ModRelationReq 实现订阅
    isFollowed.value = !isFollowed.value;
  }

  Widget videoWidget() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  @override
  void onClose() {
    _videoController?.dispose();
    _danmakuClient?.disconnect();
    inputController.dispose();
    super.onClose();
  }
}
