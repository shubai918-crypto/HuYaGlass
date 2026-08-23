import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:live_core/live_core.dart';

import '../home/follow_store.dart';
import 'background_play.dart';

class _Quality {
  final String name;
  final int ratio;
  const _Quality(this.name, this.ratio);
}

class _Line {
  final String name;
  final String hlsUrl;
  final String suffix;
  final String anti;
  const _Line(this.name, this.hlsUrl, this.suffix, this.anti);
}

class LivePlayPage extends StatefulWidget {
  const LivePlayPage({super.key});
  @override
  State<LivePlayPage> createState() => _LivePlayPageState();
}

class _LivePlayPageState extends State<LivePlayPage> {
  late final String _roomId;
  String _nickname = '';
  String _avatar = '';
  String _intro = '';
  int _fans = 0;
  int _startTime = 0;
  bool _isLive = false;
  bool _followed = false;
  bool _loading = true;
  String _status = '';

  Timer? _tickTimer;
  VideoPlayerController? _controller;

  final HuyaDanmakuClient _danmaku = HuyaDanmakuClient();
  final List<DanmakuMessage> _messages = [];
  final TextEditingController _sendCtrl = TextEditingController();

  String _streamName = '';
  List<_Quality> _qualities = [];
  int _qi = 0;
  List<_Line> _lines = [];
  int _li = 0;

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _roomId = '${args['roomId'] ?? ''}';
    _nickname = '${args['nickname'] ?? ''}';
    _avatar = '${args['avatarUrl'] ?? ''}';

    _danmaku.onStatus = (s) {
      if (mounted) setState(() => _status = s);
    };
    _danmaku.danmakuStream.listen((m) {
      if (mounted) {
        setState(() {
          _messages.add(m);
          if (_messages.length > 300) _messages.removeAt(0);
        });
      }
    });

    _followedCheck();
    _load();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _controller?.dispose();
    _danmaku.disconnect();
    _sendCtrl.dispose();
    super.dispose();
  }

  Future<void> _followedCheck() async {
    final v = await FollowStore.contains(_roomId);
    if (mounted) setState(() => _followed = v);
  }

  Future<void> _toggleFollow() async {
    if (_followed) {
      await FollowStore.remove(_roomId);
    } else {
      await FollowStore.add(
          FollowItem(roomId: _roomId, name: _nickname, avatar: _avatar));
    }
    setState(() => _followed = !_followed);
  }

  // ================= 解析（空安全 + 正确开播判断） =================
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(
        Uri.parse(
            'https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$_roomId'),
        headers: {'User-Agent': _ua},
      );
      final j = jsonDecode(resp.body);
      final data = (j is Map ? j['data'] : null) as Map? ?? {};
      final live = (data['liveData'] as Map?) ?? {};
      final stream = data['stream'] as Map?;
      final base = stream?['baseStream'] as Map?;

      _streamName = '${base?['sStreamName'] ?? ''}';

      final liveStatus = '${data['liveStatus'] ?? ''}'.toUpperCase();
      final isOn = data['isOn'] == 1 ||
          live['isOn'] == 1 ||
          liveStatus == 'ON' ||
          liveStatus == 'LIVE' ||
          (base != null && _streamName.isNotEmpty);

      int st = 0;
      for (final k in ['startTime', 'iStartTime', 'lStartTime']) {
        if (live[k] is num) {
          st = (live[k] as num).toInt();
          break;
        }
        if (base?[k] is num) {
          st = (base![k] as num).toInt();
          break;
        }
      }

      setState(() {
        _nickname = _nickname.isEmpty ? '${live['nick'] ?? ''}' : _nickname;
        _avatar = _avatar.isEmpty ? '${live['avatar180'] ?? ''}' : _avatar;
        _intro = '${live['introduction'] ?? live['slogan'] ?? ''}';
        _fans = (live['totalCount'] is num)
            ? (live['totalCount'] as num).toInt()
            : 0;
        _isLive = isOn;
        _startTime = st;
      });

      _tickTimer?.cancel();
      if (isOn && st > 0) {
        _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }

      final multi = (stream?['hlsMultiLine'] as List?) ?? [];
      _lines = [
        if (base != null)
          _Line('线路1', '${base['sHlsUrl'] ?? ''}',
              '${base['sHlsUrlSuffix'] ?? ''}', '${base['sHlsAntiCode'] ?? ''}'),
        for (final m in multi)
          if (m is Map)
            _Line(
              '${m['sCdnType'] ?? '线路'}',
              '${m['sHlsUrl'] ?? base?['sHlsUrl'] ?? ''}',
              '${m['sHlsUrlSuffix'] ?? base?['sHlsUrlSuffix'] ?? ''}',
              '${m['sHlsAntiCode'] ?? base?['sHlsAntiCode'] ?? ''}',
            ),
      ];

      final rates = (stream?['flvRateArray'] as List?) ?? [];
      _qualities = [
        for (final r in rates)
          if (r is Map)
            _Quality('${r['sName'] ?? ''}',
                (r['iBitRate'] is num) ? (r['iBitRate'] as num).toInt() : 0),
      ];
      if (_qualities.isEmpty) {
        _qualities = const [
          _Quality('蓝光10M', 0),
          _Quality('蓝光4M', 1000),
          _Quality('超清', 2000),
          _Quality('流畅', 3000),
        ];
      }

      final sid = int.tryParse(_roomId) ?? 0;
      _danmaku.connect(topSid: sid, subSid: sid, roomIdStr: _roomId);

      if (isOn && _streamName.isNotEmpty) {
        await _play();
      } else if (isOn) {
        setState(() => _status = '在播但流信息为空');
      }
    } catch (e) {
      setState(() => _status = '加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildUrl() {
    if (_lines.isEmpty || _streamName.isEmpty) return '';
    final line = _lines[_li];
    final ratio = _qualities.isEmpty ? 0 : _qualities[_qi].ratio;
    final anti = line.anti.isEmpty ? '' : '&${line.anti}';
    return '${line.hlsUrl}/$_streamName.${line.suffix}?ratio=$ratio$anti';
  }

  Future<void> _play() async {
    final url = _buildUrl();
    if (url.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _controller?.dispose();
      _controller = null;
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent': _ua,
          'Referer': 'https://www.huya.com/',
        },
      );
      _controller = c;
      await c.initialize();
      c.setLooping(false);
      await c.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _status = '播放失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _wan(int n) =>
      n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '$n';

  String _liveDurationText() {
    if (_startTime <= 0 || !_isLive) return '';
    final dur = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(_startTime * 1000));
    if (dur.isNegative) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    final s = dur.inSeconds % 60;
    return h > 0
        ? '${two(h)}:${two(m)}:${two(s)}'
        : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundPlayGuard(
      onPause: () => _controller?.pause(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            _buildHeader(context),
            _buildVideo(),
            Expanded(child: _buildTabs()),
            _buildBottom(context), // ★ 固定紧凑，不再挤压
          ],
        ),
      ),
    );
  }

  // ================= 头部 =================
  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final dur = _liveDurationText();
    return Container(
      color: const Color(0xFF101018),
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            backgroundImage: _avatar.isNotEmpty ? NetworkImage(_avatar) : null,
            child: _avatar.isEmpty
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nickname.isEmpty ? '虎牙主播' : _nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  '粉丝 ${_wan(_fans)}${dur.isNotEmpty ? ' · 已播 $dur' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _toggleFollow,
            style: TextButton.styleFrom(
              side: BorderSide(
                  color: _followed ? const Color(0xFFE5484D) : Colors.white24),
            ),
            child: Text(
              _followed ? '已订阅' : '订阅',
              style: TextStyle(
                  color: _followed ? const Color(0xFFE5484D) : Colors.white70),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  // ================= 视频区 =================
  Widget _buildVideo() {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          if (_isLive && ready)
            Center(
              child: AspectRatio(
                aspectRatio:
                    c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
                child: VideoPlayer(c),
              ),
            )
          else if (_isLive)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00D2FF)),
                  SizedBox(height: 10),
                  Text('直播流加载/解析中…',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            )
          else
            const Center(
              child: Text('主播未开播\n当前直播间没有在直播',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70)),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: _load,
                ),
                const BackgroundPlayToggleButton(),
              ],
            ),
          ),
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D2FF))),
          Positioned(
            left: 8,
            bottom: 6,
            child: Text(_status,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ================= 弹幕/详情 =================
  Widget _buildTabs() {
    final dur = _liveDurationText();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white54,
            indicatorColor: Color(0xFF00D2FF),
            tabs: [Tab(text: '弹幕'), Tab(text: '主播详情')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (c, i) {
                    final m = _messages[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '${m.nickname}: ',
                            style: const TextStyle(
                                color: Color(0xFF29C5F6),
                                fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: m.content,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.87)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text('房间号：$_roomId',
                        style: const TextStyle(color: Colors.white70)),
                    Text('昵称：$_nickname',
                        style: const TextStyle(color: Colors.white70)),
                    Text('粉丝：${_wan(_fans)}',
                        style: const TextStyle(color: Colors.white70)),
                    Text(_isLive ? '状态：直播中' : '状态：未开播',
                        style: const TextStyle(color: Colors.white70)),
                    if (dur.isNotEmpty)
                      Text('开播时长：$dur',
                          style: const TextStyle(color: Colors.white70)),
                    if (_intro.isNotEmpty)
                      Text('简介：$_intro',
                          style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= 底部：横滑芯片 + 固定发送栏 =================
  Widget _buildBottom(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF101018),
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLive && _qualities.isNotEmpty)
            _chipRow(
              labels: [for (final q in _qualities) q.name],
              selected: _qi,
              onSelected: (i) {
                setState(() => _qi = i);
                _play();
              },
            ),
          if (_isLive && _qualities.isNotEmpty && _lines.isNotEmpty)
            const SizedBox(height: 6),
          if (_isLive && _lines.isNotEmpty)
            _chipRow(
              labels: [for (final l in _lines) l.name],
              selected: _li,
              onSelected: (i) {
                setState(() => _li = i);
                _play();
              },
            ),
          const SizedBox(height: 8),
          _sendBar(),
        ],
      ),
    );
  }

  /// ★ 单行横向滑动芯片，不再换行占高度
  Widget _chipRow({
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) => ChoiceChip(
          label: Text(labels[i]),
          selected: selected == i,
          selectedColor: const Color(0xFF00D2FF),
          backgroundColor: Colors.white.withOpacity(0.06),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          labelStyle: TextStyle(
              color: selected == i ? Colors.black87 : Colors.white70),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => onSelected(i),
        ),
      ),
    );
  }

  Widget _sendBar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: TextField(
              controller: _sendCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '发送弹幕...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(23),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.send, color: Color(0xFF00D2FF)),
          onPressed: () async {
            final t = _sendCtrl.text.trim();
            if (t.isEmpty) return;
            await _danmaku.sendDanmaku(t);
            _sendCtrl.clear();
          },
        ),
      ],
    );
  }
}
