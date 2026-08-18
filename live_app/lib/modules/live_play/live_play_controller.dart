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
  final debugInfo = ''.obs;

  final qualities = <StreamQuality>[].obs;
  Stream<DanmakuMessage>? danmakuStream;

  final Player player = Player();
  late final VideoController videoController = VideoController(player);

  final List<String> _candidates = [];
  String _currentUrl = '';
  bool _playing = false;
  int _vw = 0;
  int _vh = 0;
  Timer? _playTimeout;

  HuyaDanmakuClient? _danmakuClient;
  final inputController = TextEditingController();
  final HuyaStreamResolver _resolver = HuyaStreamResolver();
  final HuyaLoginManager _loginManager = HuyaLoginManager();

  @override
  void onInit() {
    super.onInit();
    _setupPlayer();
    _loadStream();
  }

  void _setupPlayer() {
    // 关键：强制软件解码，避免硬解黑屏
    try {
      player.setProperty('hwdec', 'no');
    } catch (_) {}

    player.stream.playing.listen((p) {
      if (p) {
        _playing = true;
        _playTimeout?.cancel();
        _updateDebug();
      }
    });
    player.stream.width.listen((w) {
      _vw = w;
      _updateDebug();
    });
    player.stream.height.listen((h) {
      _vh = h;
      _updateDebug();
    });
    player.stream.error.listen((err) {
      debugPrint('PLAYER ERROR: $err');
      _tryNext('出错');
    });
  }

  void _updateDebug() {
    if (_playing) debugInfo.value = '播放中 ✔ ${_vw}x$_vh';
  }

  Future<void> _loadStream() async {
    try {
      final info = await _resolver.resolveStream(roomId);
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
      } else {
        debugInfo.value = '未解析到线路(可能未开播)';
      }

      if (isLive.value) _connectDanmaku(info.presenterUid);
      loading.value = false;
    } catch (e) {
      loading.value = false;
      Get.snackbar('错误', '加载失败: $e');
    }
  }

  void _playStream(StreamQuality q) {
    _candidates
      ..clear()
      ..addAll(q.candidates);
    _playing = false;
    _vw = 0;
    _vh = 0;
    _tryNext('首条线路');
  }

  void _tryNext(String reason) {
    _playTimeout?.cancel();
    if (_playing) return;
    if (_candidates.isEmpty) {
      debugInfo.value = '全部线路失败 ✘';
      Get.snackbar('播放失败', '所有线路均失败，主播可能未开播',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4));
      return;
    }
    final url = _candidates.removeAt(0);
    _currentUrl = url;
    debugInfo.value = '[$reason] 尝试: ${url.length > 50 ? '${url.substring(0, 50)}…' : url}';
    player.open(
      Media(url, httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://www.huya.com/',
      }),
      play: true,
    );
    _playTimeout = Timer(const Duration(seconds: 8), () {
      if (!_playing) _tryNext('超时');
    });
  }

  void switchQuality(StreamQuality q) {
    currentQuality.value = q.name;
    _playing = false;
    _playStream(q);
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

  Widget videoWidget() {
    return Stack(
      children: [
        Video(
          controller: videoController,
          fit: BoxFit.contain,
          controls: (state) => const SizedBox.shrink(),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Obx(() => Text(
                debugInfo.value,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              )),
        ),
      ],
    );
  }

  @override
  void onClose() {
    _playTimeout?.cancel();
    _danmakuClient?.disconnect();
    player.dispose();
    inputController.dispose();
    super.onClose();
  }
}
