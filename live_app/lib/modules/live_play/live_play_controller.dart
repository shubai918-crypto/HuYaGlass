import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:video_player/video_player.dart';

class LivePlayController extends GetxController {
  final roomId = Get.parameters['roomId'] ?? '';
  final streamerUid = int.tryParse(Get.parameters['uid'] ?? '0') ?? 0;

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

  @override
  void onInit() {
    super.onInit();
    _loadStream();
  }

  Future<void> _loadStream() async {
    try {
      final info = await _streamResolver.resolveStream(roomId);
      if (info == null) {
        Get.snackbar('错误', '无法获取直播流');
        return;
      }

      streamerName.value = info.presenterName;
      fansCount.value = info.fansCount;
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
    _danmakuClient = HuyaDanmakuClient();
    _danmakuClient!.connect(
      uid: 0, // 未登录时为 0
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
    // TODO: 实现发送弹幕（需要登录态）
    inputController.clear();
    Get.snackbar('提示', '发送弹幕需要登录');
  }

  void toggleFollow() {
    // TODO: 实现订阅（需要登录态）
    Get.snackbar('提示', '订阅需要登录');
  }

  Widget videoWidget() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
