import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../home/follow_store.dart';

class LivePlayController extends GetxController {
  final roomId = _readRoomId();
  final presenterUid = int.tryParse(Get.parameters['uid'] ?? '0') ?? 0;

  static String _readRoomId() {
    final p = Get.parameters['roomId'];
    if (p != null && p.isNotEmpty) return p;
    final a = Get.arguments;
    if (a is Map) {
      final v = a['roomId'];
      if (v != null) return v.toString();
    }
    return '';
  }

  static const List<String> fitNames = ['自适应', '填充', '16:9', '4:3', '铺满'];

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
  final roomTitle = ''.obs;
  final liveStartTime = 0.obs;
  final liveDurationText = ''.obs;
  Timer? _durationTimer;

  // ---------- 弹幕设置 / 省电 ----------
  final danmakuFps = 30.obs;
  final danmakuSpeed = 120.0.obs;
  final danmakuOpacity = 1.0.obs;
  final danmakuArea = 0.4.obs;
  final powerSave = false.obs;

  // ---------- 播放器控制层 ----------
  final showControls = false.obs;
  final isFullscreen = false.obs;
  final isLocked = false.obs;
  final isPaused = false.obs;
  final isMuted = false.obs;
  final fitMode = 0.obs;
  Timer? _hideTimer;

  final qualities = <StreamQuality>[].obs;
  final lines = <String>[].obs;
  final currentLine = 0.obs;
  final danmakuList = <DanmakuMessage>[].obs;
  final danmakuStatus = '弹幕连接中…'.obs;
  Stream<DanmakuMessage>? danmakuStream;

  VideoPlayerController? _controller;

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
    _loadSettings();
    _loadStream();
  }

  // ================= 设置持久化 =================
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      danmakuFps.value = prefs.getInt('dm_fps') ?? 30;
      danmakuSpeed.value = prefs.getDouble('dm_speed') ?? 120;
      danmakuOpacity.value = prefs.getDouble('dm_opacity') ?? 1.0;
      danmakuArea.value = prefs.getDouble('dm_area') ?? 0.4;
      danmakuFontSize.value = prefs.getDouble('dm_font') ?? 14;
      powerSave.value = prefs.getBool('power_save') ?? false;
      if (powerSave.value) {
        danmakuFps.value = 15;
        showDanmaku.value = false;
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dm_fps', danmakuFps.value);
      await prefs.setDouble('dm_speed', danmakuSpeed.value);
      await prefs.setDouble('dm_opacity', danmakuOpacity.value);
      await prefs.setDouble('dm_area', danmakuArea.value);
      await prefs.setDouble('dm_font', danmakuFontSize.value);
      await prefs.setBool('power_save', powerSave.value);
    } catch (_) {}
  }

  void togglePowerSave() {
    powerSave.value = !powerSave.value;
    if (powerSave.value) {
      danmakuFps.value = 15;
      showDanmaku.value = false;
      Get.snackbar('省电模式', '已开启：降弹幕帧率、关滚动弹幕', snackPosition: SnackPosition.BOTTOM);
    } else {
      danmakuFps.value = 30;
      Get.snackbar('省电模式', '已关闭', snackPosition: SnackPosition.BOTTOM);
    }
    _saveSettings();
  }

  // ================= 开播时长 =================
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _updateDuration();
    _durationTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _updateDuration());
  }

  void _updateDuration() {
    final st = liveStartTime.value;
    if (st <= 0 || !isLive.value) {
      liveDurationText.value = '';
      return;
    }
    var sec = DateTime.now().millisecondsSinceEpoch ~/ 1000 - st;
    if (sec < 0) sec = 0;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    liveDurationText.value = h > 0 ? '$h小时$m分钟' : '$m分钟';
  }

  // ================= 弹幕设置面板 =================
  void showDanmakuSettings() {
    Get.bottomSheet(
      Container(
        color: const Color(0xFF16161E),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SafeArea(
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('弹幕设置',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(showDanmaku.value ? '滚动弹幕:开' : '滚动弹幕:关',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      Switch(
                        value: showDanmaku.value,
                        activeColor: const Color(0xFF00D2FF),
                        onChanged: (v) {
                          showDanmaku.value = v;
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _seg('帧率', const ['15', '30', '60'], '${danmakuFps.value}', (v) {
                    danmakuFps.value = int.parse(v);
                    if (powerSave.value && danmakuFps.value > 15) powerSave.value = false;
                    _saveSettings();
                  }),
                  _slider('速度', 60, 300, danmakuSpeed.value, (v) {
                    danmakuSpeed.value = v;
                    _saveSettings();
                  }, '${danmakuSpeed.value.toInt()}px/s'),
                  _slider('字号', 10, 24, danmakuFontSize.value, (v) {
                    danmakuFontSize.value = v;
                    _saveSettings();
                  }, '${danmakuFontSize.value.toInt()}'),
                  _slider('透明度', 0.3, 1, danmakuOpacity.value, (v) {
                    danmakuOpacity.value = v;
                    _saveSettings();
                  }, '${(danmakuOpacity.value * 100).toInt()}%'),
                  _slider('区域', 0.2, 0.8, danmakuArea.value, (v) {
                    danmakuArea.value = v;
                    _saveSettings();
                  }, '${(danmakuArea.value * 100).toInt()}%'),
                  Row(
                    children: [
                      const Icon(Icons.battery_saver, color: Color(0xFF7ED97E), size: 20),
                      const SizedBox(width: 8),
                      const Text('省电模式',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(width: 4),
                      const Text('(降帧率+关滚动弹幕，减少发热)',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const Spacer(),
                      Switch(
                        value: powerSave.value,
                        activeColor: const Color(0xFF7ED97E),
                        onChanged: (_) => togglePowerSave(),
                      ),
                    ],
                  ),
                ],
              )),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _seg(String label, List<String> options, String current, ValueChanged<String> onPick) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 52,
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          const SizedBox(width: 8),
          ...options.map((o) => GestureDetector(
                onTap: () => onPick(o),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: o == current
                        ? const Color(0xFF00D2FF).withOpacity(0.2)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: o == current
                            ? const Color(0xFF00D2FF)
                            : Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(o,
                      style: TextStyle(
                          color: o == current ? const Color(0xFF00D2FF) : Colors.white60,
                          fontSize: 12)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _slider(String label, double min, double max, double val,
      ValueChanged<double> onChanged, String display) {
    return Row(
      children: [
        SizedBox(
            width: 52,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: Slider(
            value: val,
            min: min,
            max: max,
            activeColor: const Color(0xFF00D2FF),
            inactiveColor: Colors.white12,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 60,
            child: Text(display, style: const TextStyle(color: Colors.white54, fontSize: 12))),
      ],
    );
  }

  // ================= 卡顿检测 =================
  void _checkStall(Timer t) {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_playing) return;
    if (c.value.isBuffering) {
      _bufferingSince ??= DateTime.now();
      if (DateTime.now().difference(_bufferingSince!) > const Duration(seconds: 12)) {
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
        '状态:${isLive.value ? "ON" : "OFF"} 线路:$_candidateIndex/$_candidateTotal ${_vw}x$_vh 重连:$_reconnectCount';
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
      roomTitle.value = info.title;
      liveStartTime.value = info.startTime;
      _startDurationTimer();
      isFollowed.value = await FollowStore.isFollowed(roomId);
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
        debugInfo.value = '全部线路失败 ✘';
      }
      return;
    }
    _candidateIndex++;
    final url = _candidates.removeAt(0);
    _currentUrl = url;
    debugInfo.value = '[$reason] 尝试 $_candidateIndex/$_candidateTotal …';
    _openUrl(url);
  }

  Future<void> _openUrl(String url) async {
    final old = _controller;
    _controller = null;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    c.addListener(() {
      if (_controller != null && !identical(_controller, c)) return;
      isPaused.value = !c.value.isPlaying;
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
      await c.setVolume(isMuted.value ? 0 : 100);
      await c.play();
      _playing = true;
      isPaused.value = false;
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

  // ================= 控制层交互 =================
  void _scheduleHide(int sec) {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: sec), () {
      showControls.value = false;
    });
  }

  void onTapVideo() {
    if (isLocked.value) {
      showControls.value = true;
      _scheduleHide(2);
      return;
    }
    showControls.value = !showControls.value;
    if (showControls.value) _scheduleHide(4);
  }

  void togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (isPaused.value) {
      c.play();
    } else {
      c.pause();
    }
    _scheduleHide(4);
  }

  void toggleMute() {
    final c = _controller;
    if (c == null) return;
    isMuted.value = !isMuted.value;
    c.setVolume(isMuted.value ? 0 : 100);
    _scheduleHide(4);
  }

  void cycleFit() {
    fitMode.value = (fitMode.value + 1) % fitNames.length;
    _scheduleHide(4);
  }

  void refreshPlay() {
    if (_currentUrl.isNotEmpty) {
      _playing = false;
      _openUrl(_currentUrl);
    }
    showControls.value = false;
  }

  void toggleLock() {
    isLocked.value = !isLocked.value;
    showControls.value = !isLocked.value;
    if (showControls.value) _scheduleHide(4);
  }

  void toggleFullscreen() {
    isFullscreen.value = !isFullscreen.value;
    if (isFullscreen.value) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      isLocked.value = false;
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    showControls.value = true;
    _scheduleHide(4);
  }

  void switchQuality(StreamQuality q) {
    currentQuality.value = q.name;
    _playing = false;
    _refreshCount = 0;
    _playStream(q);
  }

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
    _danmakuClient!.onPopularity = (v) => heatCount.value = v;
    _danmakuClient!.onSendDebug = (s) => debugInfo.value = s;
    _danmakuClient!.connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid, roomIdStr: roomId);
    danmakuStream = _danmakuClient!.danmakuStream;
    danmakuStream!.listen((m) {
      danmakuList.add(m);
      if (danmakuList.length > 200) {
        danmakuList.removeRange(0, danmakuList.length - 200);
      }
    });
  }

  // ================= 发送弹幕 =================
  void sendDanmaku(String text) async {
    if (text.isEmpty) return;
    if (!_loginManager.isLoggedIn) {
      Get.snackbar('提示', '请先在 设置→虎牙账号 登录', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    inputController.clear();
    final ok = await _danmakuClient?.sendDanmaku(text) ?? false;
    if (!ok) {
      Get.snackbar('发送失败', '弹幕连接未就绪', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void toggleFollow() {
    if (!_loginManager.isLoggedIn) {
      Get.snackbar('提示', '订阅需要先登录', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    isFollowed.value = !isFollowed.value;
    if (isFollowed.value) {
      FollowStore.add(FollowItem(
        roomId: roomId,
        name: streamerName.value,
        avatar: streamerAvatar.value,
      ));
    } else {
      FollowStore.remove(roomId);
    }
  }

  void _showUrlDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('当前播放地址', style: TextStyle(color: Colors.white, fontSize: 16)),
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
            child: const Text('复制地址', style: TextStyle(color: Color(0xFF00D2FF))),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ================= 视频渲染 =================
  Widget _videoByFit(VideoPlayerController c) {
    final va = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    switch (fitMode.value) {
      case 1:
        return SizedBox.expand(child: VideoPlayer(c));
      case 2:
        return Center(child: AspectRatio(aspectRatio: 16 / 9, child: VideoPlayer(c)));
      case 3:
        return Center(child: AspectRatio(aspectRatio: 4 / 3, child: VideoPlayer(c)));
      case 4:
        return LayoutBuilder(builder: (ctx, cons) {
          final cw = cons.maxWidth, ch = cons.maxHeight;
          if (cw <= 0 || ch <= 0) {
            return Center(child: AspectRatio(aspectRatio: va, child: VideoPlayer(c)));
          }
          final ca = cw / ch;
          double w, h;
          if (va > ca) {
            h = ch;
            w = ch * va;
          } else {
            w = cw;
            h = cw / va;
          }
          return Center(
              child: ClipRect(child: SizedBox(width: w, height: h, child: VideoPlayer(c))));
        });
      default:
        return Center(child: AspectRatio(aspectRatio: va, child: VideoPlayer(c)));
    }
  }

  Widget _controlBtn(IconData icon, VoidCallback onTap,
      {bool selected = false, double size = 36}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(selected ? 0.7 : 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: selected ? const Color(0xFF7ED97E) : Colors.white, size: size * 0.55),
      ),
    );
  }

  Widget _buildControls(bool fullscreen) {
    return Stack(children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            if (fullscreen) ...[
              _controlBtn(Icons.arrow_back, toggleFullscreen, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  streamerName.value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            _controlBtn(Icons.battery_saver, togglePowerSave, selected: powerSave.value),
            const SizedBox(width: 6),
            _controlBtn(Icons.tune, showDanmakuSettings),
            if (fullscreen) ...[
              const SizedBox(width: 6),
              _controlBtn(Icons.lock_open, toggleLock, size: 40),
            ],
          ]),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            _controlBtn(isPaused.value ? Icons.play_arrow : Icons.pause, togglePlay),
            const SizedBox(width: 6),
            _controlBtn(Icons.refresh, refreshPlay),
            const SizedBox(width: 6),
            _controlBtn(showDanmaku.value ? Icons.chat : Icons.chat_bubble_outline, () {
              showDanmaku.value = !showDanmaku.value;
              _scheduleHide(4);
            }),
            const SizedBox(width: 6),
            _controlBtn(isMuted.value ? Icons.volume_off : Icons.volume_up, toggleMute),
            const SizedBox(width: 6),
            _controlBtn(Icons.aspect_ratio, cycleFit),
            const Spacer(),
            Obx(() => Text(
                  fitNames[fitMode.value],
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                )),
            const SizedBox(width: 8),
            _controlBtn(
                fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, toggleFullscreen),
          ]),
        ),
      ),
    ]);
  }

  /// 全屏覆盖层：复用竖屏播放器的 textureId 再画一层 Texture（不重建播放器，黑屏根治）
  Widget fullscreenOverlay() {
    return Obx(() {
      final c = _controller;
      final tid = c?.value.textureId; // 修正：video_player 2.x 中 textureId 在 value 内
      return GestureDetector(
        onTap: onTapVideo,
        onLongPress: _showUrlDialog,
        child: Container(
          color: Colors.black,
          child: Stack(children: [
            if (c != null && c.value.isInitialized && tid != null)
              Positioned.fill(child: _textureByFit(c, tid)),
            if (isPaused.value && !isLocked.value)
              Center(
                  child:
                      _controlBtn(Icons.play_arrow, togglePlay, selected: true, size: 64)),
            if (showControls.value && !isLocked.value) _buildControls(true),
            if (isLocked.value && showControls.value)
              Positioned(
                left: 12,
                top: 60,
                child: _controlBtn(Icons.lock, toggleLock, selected: true, size: 40),
              ),
          ]),
        ),
      );
    });
  }

  Widget _textureByFit(VideoPlayerController c, int tid) {
    final va = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    switch (fitMode.value) {
      case 1:
        return SizedBox.expand(child: Texture(textureId: tid));
      case 2:
        return Center(
            child: AspectRatio(aspectRatio: 16 / 9, child: Texture(textureId: tid)));
      case 3:
        return Center(
            child: AspectRatio(aspectRatio: 4 / 3, child: Texture(textureId: tid)));
      case 4:
        return LayoutBuilder(builder: (ctx, cons) {
          final cw = cons.maxWidth, ch = cons.maxHeight;
          if (cw <= 0 || ch <= 0) {
            return Center(
                child: AspectRatio(aspectRatio: va, child: Texture(textureId: tid)));
          }
          final ca = cw / ch;
          double w, h;
          if (va > ca) {
            h = ch;
            w = ch * va;
          } else {
            w = cw;
            h = cw / va;
          }
          return Center(
              child: ClipRect(
                  child: SizedBox(width: w, height: h, child: Texture(textureId: tid))));
        });
      default:
        return Center(
            child: AspectRatio(aspectRatio: va, child: Texture(textureId: tid)));
    }
  }

  Widget _videoCore({required bool fullscreen}) {
    return Obx(() {
      playerVersion.value; // 建立依赖：换流时重建
      final c = _controller;
      return GestureDetector(
        onTap: onTapVideo,
        onLongPress: _showUrlDialog,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              if (c != null && c.value.isInitialized)
                Positioned.fill(
                  child: KeyedSubtree(
                    key: const ValueKey('vp'),
                    child: _videoByFit(c),
                  ),
                ),
              if (isPaused.value && !isLocked.value)
                Center(
                    child:
                        _controlBtn(Icons.play_arrow, togglePlay, selected: true, size: 64)),
              if (showControls.value && !isLocked.value) _buildControls(fullscreen),
              if (isLocked.value && showControls.value)
                Positioned(
                  left: 12,
                  top: fullscreen ? 60 : 12,
                  child: _controlBtn(Icons.lock, toggleLock, selected: true, size: 40),
                ),
              if (!fullscreen)
                Positioned(
                  left: 8,
                  top: 8,
                  right: 8,
                  child: Text(
                    debugInfo.value,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget videoWidget() => _videoCore(fullscreen: false);
  Widget fullscreenWidget() => _videoCore(fullscreen: true);
  Widget videoHost(bool fullscreen) => _videoCore(fullscreen: fullscreen);

  @override
  void onClose() {
    _hideTimer?.cancel();
    _stallTimer?.cancel();
    _durationTimer?.cancel();
    _danmakuClient?.disconnect();
    _controller?.dispose();
    inputController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }
}
