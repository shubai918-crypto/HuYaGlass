import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:live_core/live_core.dart';

import '../home/follow_store.dart';

class _Quality {
  final String name;
  final int ratio;
  const _Quality(this.name, this.ratio);
}

class _Line {
  final String name;
  final Map<String, dynamic>? flv;
  final Map<String, dynamic>? hls;
  const _Line(this.name, this.flv, this.hls);
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

  // ================= 解析房间（空安全 + 正确开播判断） =================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '';
    });
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

      final streamName = '${base?['sStreamName'] ?? ''}';

      // ★ 正确开播判断
      final liveStatus = '${data['liveStatus'] ?? ''}'.toUpperCase();
      final isOn = data['isOn'] == 1 ||
          live['isOn'] == 1 ||
          liveStatus == 'ON' ||
          liveStatus == 'LIVE' ||
          (base != null && streamName.isNotEmpty);

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

      // ★ 线路：FLV + HLS 双地址
      final flvMulti = (stream?['flvMultiLine'] as List?) ?? [];
      final hlsMulti = (stream?['hlsMultiLine'] as List?) ?? [];
      _lines = [
        if (base != null) _Line('线路1', base, base),
        for (var i = 0; i < flvMulti.length; i++)
          if (flvMulti[i] is Map)
            _Line(
              '${flvMulti[i]['sCdnType'] ?? '线路${i + 2}'}',
              flvMulti[i] as Map<String, dynamic>,
              (i < hlsMulti.length && hlsMulti[i] is Map)
                  ? hlsMulti[i] as Map<String, dynamic>
                  : null,
            ),
      ];
      if (_lines.isEmpty && base != null) _lines = [_Line('线路1', base, base)];

      // 画质
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

      // 弹幕
      final sid = int.tryParse(_roomId) ?? 0;
      _danmaku.connect(topSid: sid, subSid: sid, roomIdStr: _roomId);

      if (isOn) {
        await _play();
      }
    } catch (e) {
      setState(() => _status = '加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _flvUrl(Map b, int ratio) {
    final u = '${b['sFlvUrl'] ?? ''}';
    final n = '${b['sStreamName'] ?? ''}';
    final s = '${b['sFlvUrlSuffix'] ?? 'flv'}';
    final a = '${b['sFlvAntiCode'] ?? ''}';
    if (u.isEmpty || n.isEmpty) return '';
    return '$u/$n.$s?$a${ratio > 0 ? '&ratio=$ratio' : ''}';
  }

  String _hlsUrl(Map b, int ratio) {
    final u = '${b['sHlsUrl'] ?? ''}';
    final n = '${b['sStreamName'] ?? ''}';
    final s = '${b['sHlsUrlSuffix'] ?? 'm3u8'}';
    final a = '${b['sHlsAntiCode'] ?? ''}';
    if (u.isEmpty || n.isEmpty) return '';
    return '$u/$n.$s?$a${ratio > 0 ? '&ratio=$ratio' : ''}';
  }

  // ★ FLV 优先 + HLS 兜底 + 10 秒超时，杜绝无限加载
  Future<void> _play() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    final line = _lines.isEmpty ? null : _lines[_li];
    if (line == null) {
      setState(() {
        _loading = false;
        _status = '无流信息';
      });
      return;
    }
    final ratio = _qualities.isEmpty ? 0 : _qualities[_qi].ratio;
    final candidates = <String>[
      if (line.flv != null) _flvUrl(line.flv!, ratio),
      if (line.hls != null) _hlsUrl(line.hls!, ratio),
    ].where((u) => u.contains('://')).toList();

    Object? lastErr;
    for (final url in candidates) {
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
        await c.initialize().timeout(const Duration(seconds: 10));
        c.setLooping(false);
        await c.play();
        if (mounted) setState(() {});
        if (mounted) setState(() => _loading = false);
        return;
      } catch (e) {
        lastErr = e;
      }
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _status = '播放失败: $lastErr';
      });
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(context),
          _buildVideo(),
          Expanded(child: _buildTabs()),
          _buildBottom(context),
        ],
      ),
    );
  }

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
          else if (_isLive && _loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
            )
          else if (_isLive)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 32),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                        _status.isNotEmpty ? _status : '播放初始化失败',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  const Text('点击右上角刷新重试',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
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
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _load,
            ),
          ),
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
