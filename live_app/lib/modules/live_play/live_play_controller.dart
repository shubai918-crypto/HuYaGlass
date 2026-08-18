import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final VideoController videoController = VideoController(
    player,
    configuration: const VideoControllerConfiguration(
      androidAttachSurfaceAfterVideoParameters: false,
    ),
  );

  final List<String> _candidates = [];
  String _currentUrl = '';
  String _lastError = '';
  int _candidateIndex = 0;
  int _candidateTotal = 0;
  int _reconnectCount = 0;
  int _refreshCount = 0;
  bool _playing = false;
  int _vw = 0;
  int _vh = 0;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _playTimeout;
  Timer? _stallTimer;

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
    _tunePlayer();

    player.stream.playing.listen((p) {
      if (p) {
        _playing = true;
        _playTimeout?.cancel();
        _updateDebug();
      }
    });
    player.stream.width.listen((w) {
      _vw = w ?? 0;
      _updateDebug();
    });
    player.stream.height.listen((h) {
      _vh = h ?? 0;
      _updateDebug();
    });
    // 打开失败 → 换下一条线路（不重试坏地址）
    player.stream.error.listen((err) {
      _lastError = '$err';
      debugPrint('PLAYER ERROR: $err');
      _advance('出错');
    });
    // 播放中卡住 → 重试当前地址（它刚才在播）
    player.stream.buffering.listen((b) {
      if (b) {
        _stallTimer?.cancel();
        _stallTimer = Timer(const Duration(seconds: 10), () {
          if (_playing) _retryCurrent('卡顿');
        });
      } else {
        _stallTimer?.cancel();
      }
    });
    player.stream.completed.listen((c) {
      if (c) _retryCurrent('结束');
    });
  }

  Future<void> _tunePlayer() async {
    try {
      final native = player.platform as dynamic;
      await native.setProperty('stream-lavf-options',
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=3');
    } catch (_) {}
  }

  bool _throttled() {
    final now = DateTime.now();
    if (now.difference(_lastAt).inMilliseconds < 800) return true;
    _lastAt = now;
    return false;
  }

  /// 出错：跳到下一条候选
  void _advance(String reason) {
    if (_throttled()) return;
    _playing = false;
    _reconnectCount++;
    _tryNext(reason);
  }

  /// 卡顿/结束：把当前地址插回队首重试
  void _retryCurrent(String reason) {
    if (_throttled()) return;
    _playing = false;
    _reconnectCount++;
    if (_currentUrl.isNotEmpty && !_candidates.contains(_currentUrl)) {
      _candidates.insert(0, _currentUrl);
      _candidateTotal = _candidates.length;
      _candidateIndex = max(0, _candidateIndex - 1);
    }
    _tryNext(reason);
  }

  void _updateDebug() {
    debugInfo.value =
        '状态:${isLive.value ? "ON" : "OFF"} 线路:$_candidateIndex/$_candidateTotal ${_vw}x$_vh 重连:$_reconnectCount (点我复制地址)';
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
        final keep = currentQuality.value;
        final q = qualities.firstWhere(
          (e) => e.name == keep,
          orElse: () => qualities.first,
        );
        currentQuality.value = q.name;
        _playStream(q);
      } else {
        debugInfo.value = '未解析到线路(可能未开播)';
      }

      if (isLive.value && _danmakuClient == null) {
        _connectDanmaku(info.presenterUid);
      }
      loading.value = false;
      _updateDebug();
    } catch (e) {
      loading.value = false;
      Get.snackbar('错误', '加载失败: $e');
    }
  }

  void _playStream(StreamQuality q) {
    _candidates
      ..clear()
      ..addAll(q.candidates);
    _candidateTotal = _candidates.length;
    _candidateIndex = 0;
    _playing = false;
    _vw = 0;
    _vh = 0;
    _tryNext('首条线路');
  }

  void _tryNext(String reason) {
    _playTimeout?.cancel();
    if (_playing) return;
    if (_candidates.isEmpty) {
      // 全部失败 → 重新解析一批新地址（最多3轮）
      if (_refreshCount < 3) {
        _refreshCount++;
        debugInfo.value = '[$reason] 重新解析线路…';
        _loadStream();
      } else {
        debugInfo.value = '全部线路失败 ✘ (点我查看地址)';
      }
      return;
    }
    _candidateIndex++;
    final url = _candidates.removeAt(0);
    _currentUrl = url;
    debugInfo.value = '[$reason] 尝试 $_candidateIndex/$_candidateTotal …';
    player.open(Media(url), play: true);
    _playTimeout = Timer(const Duration(seconds: 8), () {
      if (!_playing) _advance('超时');
    });
  }

  void _showUrlDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('当前播放地址',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              _currentUrl.isEmpty ? '（还没有地址）' : _currentUrl,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '状态:${isLive.value ? "ON" : "OFF"} 分辨率:${_vw}x$_vh 重连:$_reconnectCount\n错误:$_lastError',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentUrl));
              Get.back();
              Get.snackbar('已复制', '把地址粘贴到浏览器打开验证');
            },
            child: const Text('复制地址',
                style: TextStyle(color: Color(0xFF00D2FF))),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void switchQuality(StreamQuality q) {
    currentQuality.value = q.name;
    _playing = false;
    _refreshCount = 0;
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
    return GestureDetector(
      onTap: _showUrlDialog,
      child: Stack(
        children: [
          Video(
            controller: videoController,
            fit: BoxFit.contain,
            controls: (state) => const SizedBox.shrink(),
          ),
          Positioned(
            left: 8,
            bottom: 130,
            right: 8,
            child: Obx(() => Text(
                  debugInfo.value,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                )),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    _playTimeout?.cancel();
    _stallTimer?.cancel();
    _danmakuClient?.disconnect();
    player.dispose();
    inputController.dispose();
    super.onClose();
  }
}
