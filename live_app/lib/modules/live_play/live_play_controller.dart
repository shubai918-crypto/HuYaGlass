import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:video_player/video_player.dart';

class LivePlayController extends GetxController {
  final roomId = Get.parameters['roomId'] ?? '';
  final presenterUid = int.tryParse(Get.parameters['uid'] ?? '0') ?? 0;

  // ---------- UI 状态 ----------
  final loading = true.obs;
  final isLive = false.obs;
  final streamerName = ''.obs;
  final streamerAvatar = ''.obs;
  final fansCount = 0.obs;
  final heatCount = 0.obs;
  final isFollowed = false.obs;
  final showDanmaku = true.obs;
  final danmakuFontSize = 14.0.obs;
  final currentQuality = ''.obs;
  final debugInfo = ''.obs;
  final playerVersion = 0.obs;

  final qualities = <StreamQuality>[].obs;
  final lines = <String>[].obs;
  final currentLine = 0.obs;
  final danmakuList = <DanmakuMessage>[].obs;
  final danmakuStatus = '弹幕连接中…'.obs;
  Stream<DanmakuMessage>? danmakuStream;

  VideoPlayerController? _controller;

  // ---------- 线路 / 重连 ----------
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
  DateTime? _bufferingSince;
  Timer? _stallTimer;

  // ---------- 弹幕参数 ----------
  int _ayyuid = 0;
  int _topSid = 0;
  int _subSid = 0;
  HuyaDanmakuClient? _danmakuClient;

  final inputController = TextEditingController();
  final HuyaStreamResolver _resolver = HuyaStreamResolver();
  final HuyaLoginManager _loginManager = HuyaLoginManager();

  @override
  void onInit() {
    super.onInit();
    _stallTimer = Timer.periodic(const Duration(seconds: 3), _checkStall);
    _loadStream();
  }

  // 直播流 position 不前进，只能用 isBuffering 判断卡顿
  void _checkStall(Timer t) {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_playing) return;
    if (c.value.isBuffering) {
      _bufferingSince ??= DateTime.now();
      if (DateTime.now().difference(_bufferingSince!) >
          const Duration(seconds: 12)) {
        _bufferingSince = null;
        _advance('卡顿');
      }
    } else {
      _bufferingSince = null;
    }
  }

  bool _throttled() {
    final now = DateTime.now();
    if (now.difference(_lastAt).inMilliseconds < 1500) return true;
    _lastAt = now;
    return false;
  }

  void _advance(String reason) {
    if (_throttled()) return;
    _playing = false;
    _reconnectCount++;
    _tryNext(reason);
  }

  void _updateDebug() {
    debugInfo.value =
        '状态:${isLive.value ? "ON" : "OFF"} 线路:$_candidateIndex/$_candidateTotal ${_vw}x$_vh 重连:$_reconnectCount (点我复制地址)';
  }

  // ================= 加载房间 =================
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
      heatCount.value = info.heat;
      isLive.value = info.isLive;
      qualities.assignAll(info.qualities);

      if (qualities.isNotEmpty) {
        final keep = currentQuality.value;
        final q = qualities.firstWhere(
          (e) => e.name == keep && keep.isNotEmpty,
          orElse: () => qualities.first,
        );
        currentQuality.value = q.name;
        _playStream(q);
      } else {
        debugInfo.value = '未解析到线路(可能未开播)';
      }

      _ayyuid = info.ayyuid;
      _topSid = info.topSid != 0 ? info.topSid : info.presenterUid;
      _subSid = info.subSid;
      if (isLive.value && _danmakuClient == null) {
        _connectDanmaku();
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
    lines.assignAll(q.candidates);
    currentLine.value = 0;
    _candidateTotal = _candidates.length;
    _candidateIndex = 0;
    _playing = false;
    _vw = 0;
    _vh = 0;
    _tryNext('首条线路');
  }

  void _tryNext(String reason) {
    if (_playing) return;
    if (_candidates.isEmpty) {
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
    _openUrl(url);
  }

  // ================= ExoPlayer 播放 =================
  Future<void> _openUrl(String url) async {
    final old = _controller;
    _controller = null;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    c.addListener(() {
      if (_controller != null && !identical(_controller, c)) return;
      if (c.value.hasError) {
        _lastError = c.value.errorDescription ?? '播放器错误';
        debugPrint('PLAYER ERROR: $_lastError');
        _advance('出错');
      }
    });
    try {
      await c.initialize().timeout(const Duration(seconds: 8));
      await old?.dispose();
      _controller = c;
      await c.play();
      _playing = true;
      _bufferingSince = null;
      _vw = c.value.size.width.toInt();
      _vh = c.value.size.height.toInt();
      _lastError = '';
      playerVersion.value++;
      _updateDebug();
    } catch (e) {
      _lastError = '$e';
      await c.dispose();
      _advance('打开失败');
    }
  }

  // ================= 调试弹窗 =================
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

  // ================= 交互 =================
  void switchQuality(StreamQuality q) {
    currentQuality.value = q.name;
    _playing = false;
    _refreshCount = 0;
    _playStream(q);
  }

  /// 手动切换 CDN 线路
  void switchLine(int i) {
    if (i < 0 || i >= lines.length) return;
    currentLine.value = i;
    _playing = false;
    _refreshCount = 0;
    _candidateIndex = i + 1;
    _candidateTotal = lines.length;
    final url = lines[i];
    _currentUrl = url;
    debugInfo.value = '手动切换线路${i + 1}';
    _openUrl(url);
  }

  void _connectDanmaku() {
    _danmakuClient = HuyaDanmakuClient();
    _danmakuClient!.onStatus = (s) => danmakuStatus.value = s;
    final roomNum = int.tryParse(roomId) ?? 0;
    final ts = _topSid != 0 ? _topSid : (roomNum != 0 ? roomNum : _ayyuid);
    final ss = _subSid != 0 ? _subSid : ts;
    _danmakuClient!.connect(topSid: ts, subSid: ss, uid: _ayyuid);
    danmakuStream = _danmakuClient!.danmakuStream;
    danmakuStream!.listen((m) {
      danmakuList.add(m);
      if (danmakuList.length > 200) {
        danmakuList.removeRange(0, danmakuList.length - 200);
      }
    });
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

  // ================= 播放器组件 =================
  Widget videoWidget() {
    return Obx(() {
      playerVersion.value;
      final c = _controller;
      return GestureDetector(
        onTap: _showUrlDialog,
        child: Stack(
          children: [
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 130,
              right: 8,
              child: Text(
                debugInfo.value,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  void onClose() {
    _stallTimer?.cancel();
    _danmakuClient?.disconnect();
    _controller?.dispose();
    inputController.dispose();
    super.onClose();
  }
}
