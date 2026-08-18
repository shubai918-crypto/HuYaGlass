import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class LivePlayController extends GetxController {
  final roomId = Get.parameters['roomId'] ?? '';
  final presenterUid = int.tryParse(Get.parameters['uid'] ?? '0') ?? 0;

  final loading = true.obs;
  final isLive = false.obs;
  final streamerName = ''.obs;
  final streamerAvatar = ''.obs;
  final fansCount = 0.obs;
  final isFollowed = false.obs;
  final showDanmaku = true.obs;
  final danmakuFontSize = 14.0.obs;
  final currentQuality = ''.obs;

  final qualities = <StreamQuality>[].obs;
  Stream<DanmakuMessage>? danmakuStream;

  // media_kit 播放器
  final Player player = Player();
  late final VideoController videoController = VideoController(player);

  HuyaDanmakuClient? _danmakuClient;
  final inputController = TextEditingController();
  final HuyaStreamResolver _streamResolver = HuyaStreamResolver();
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
        loading.value = false;
        Get.snackbar('错误', '无法获取直播流', snackPosition: SnackPosition.TOP);
        return;
      }

      streamerName.value = info.streamerInfo.nickname;
      streamerAvatar.value = info.streamerInfo.avatar;
      fansCount.value = info.streamerInfo.fansCount;
      isLive.value = info.isLive;
      qualities.assignAll(info.qualities);

      if (qualities.isNotEmpty) {
        currentQuality.value = qualities.first.name;
        _playStream(qualities.first);
      }

      if (isLive.value) {
        _connectDanmaku(info.presenterUid);
      }
      loading.value = false;
    } catch (e) {
      loading.value = false;
      Get.snackbar('错误', '加载失败: $e');
    }
  }

  void _playStream(StreamQuality quality) {
    // 优先 HLS，失败时 media_kit 也能播 FLV
    final url = quality.hlsUrl.isNotEmpty ? quality.hlsUrl : quality.flvUrl;
    player.open(
      Media(url, httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://www.huya.com/',
      }),
      play: true,
    );
  }

  void switchQuality(StreamQuality quality) {
    currentQuality.value = quality.name;
    _playStream(quality);
  }

  void _connectDanmaku(int presenterUid) {
    _danmakuClient = HuyaDanmakuClient(_loginManager);
    _danmakuClient!.connect(roomId: roomId, presenterUid: presenterUid);
    danmakuStream = _danmakuClient!.danmakuStream;
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
    isFollowed.value = !isFollowed.value;
  }

  /// 播放器组件
  Widget videoWidget() {
    return Video(
      controller: videoController,
      fit: BoxFit.contain,
      controls: (state) => const SizedBox.shrink(),
    );
  }

  @override
  void onClose() {
    _danmakuClient?.disconnect();
    player.dispose();
    inputController.dispose();
    super.onClose();
  }
}
