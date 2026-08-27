import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'live_play_controller.dart';

class LivePlayPage extends StatefulWidget {
  const LivePlayPage({super.key});
  @override
  State<LivePlayPage> createState() => _LivePlayPageState();
}

class _LivePlayPageState extends State<LivePlayPage>
    with SingleTickerProviderStateMixin {
  late final LivePlayController c = Get.put(LivePlayController());
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    Get.delete<LivePlayController>();
    super.dispose();
  }

  String _fmt(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() =>
        c.isFullscreen.value ? _buildFullscreen() : _buildPortrait(context));
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(children: [
          c.videoHost(true),
          DanmakuOverlay(c: c),
        ]),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Column(children: [
        SizedBox(height: top),
        _header(),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(children: [
            c.videoHost(false),
            DanmakuOverlay(c: c),
          ]),
        ),
        _tabs(),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            _DanmakuList(c: c),
            _DetailTab(c: c),
          ]),
        ),
        _bottomBar(),
      ]),
    );
  }

  Widget _header() {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white10,
              backgroundImage: c.streamerAvatar.value.isNotEmpty
                  ? NetworkImage(c.streamerAvatar.value)
                  : null,
              child: c.streamerAvatar.value.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        c.streamerName.value.isEmpty
                            ? '—'
                            : c.streamerName.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('粉丝 ${_fmt(c.fansCount.value)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
            ),
            GestureDetector(
              onTap: c.toggleFollow,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0x33E5484D),
                    border: Border.all(color: const Color(0xFFE5484D)),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c.isFollowed.value ? '已订阅' : '订阅',
                    style:
                        const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Colors.white10, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ),
          ]),
        ));
  }

  Widget _tabs() {
    return Container(
      color: const Color(0xFF101018),
      child: TabBar(
        controller: _tab,
        indicatorColor: const Color(0xFF00D2FF),
        labelColor: const Color(0xFF00D2FF),
        unselectedLabelColor: Colors.white54,
        tabs: const [Tab(text: '弹幕'), Tab(text: '主播详情')],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: const Color(0xFF101018),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 34,
          child: Obx(() => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.qualities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final q = c.qualities[i];
                  final sel = q.name == c.currentQuality.value;
                  return GestureDetector(
                    onTap: () => c.switchQuality(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00D2FF).withOpacity(0.12)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(q.name,
                          style: TextStyle(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white60,
                              fontSize: 12)),
                    ),
                  );
                },
              )),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: Obx(() => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.lines.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = i == c.currentLine.value;
                  return GestureDetector(
                    onTap: () => c.switchLine(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00D2FF).withOpacity(0.12)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(14)),
                      child: Text('线路${i + 1}',
                          style: TextStyle(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white60,
                              fontSize: 12)),
                    ),
                  );
                },
              )),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22)),
              child: TextField(
                controller: c.inputController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    hintText: '发送弹幕...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none),
                onSubmitted: (t) => c.sendDanmaku(t),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => c.sendDanmaku(c.inputController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Color(0xFF00D2FF), shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ================= ★ 飘屏弹幕层 =================
class _FloatItem {
  final String text;
  final Color color;
  final double w;
  double x;
  final double y;
  _FloatItem(this.text, this.color, this.x, this.y, this.w);
}

class _PendingItem {
  final DanmakuMessage m;
  final int born;
  _PendingItem(this.m, this.born);
}

class DanmakuOverlay extends StatefulWidget {
  final LivePlayController c;
  const DanmakuOverlay({super.key, required this.c});
  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  final List<_FloatItem> _items = [];
  final List<_PendingItem> _queue = [];
  final List<int> _laneFreeAt = [];
  Ticker? _ticker;
  StreamSubscription? _sub;
  int _lastNow = 0;
  double _w = 0;
  double _h = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _sub = widget.c.danmakuList.listen((_) {
      if (widget.c.danmakuList.isNotEmpty) {
        final m = widget.c.danmakuList.last;
        if (!m.isHistory) _enqueue(m);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  double _lineHeight() => widget.c.danmakuFontSize.value * 1.8;

  void _syncLanes() {
    final n = max(1, (_h * widget.c.danmakuArea.value / _lineHeight()).floor());
    if (_laneFreeAt.length != n) {
      _laneFreeAt.clear();
      _laneFreeAt.addAll(List.filled(n, 0));
    }
  }

  void _enqueue(DanmakuMessage m) {
    if (!widget.c.showDanmaku.value || _w <= 0 || _h <= 0) return;
    if (_queue.length > 40) _queue.removeAt(0);
    _queue.add(_PendingItem(m, DateTime.now().millisecondsSinceEpoch));
  }

  double _measure(String text, double fs) {
    double w = 8;
    for (final r in text.runes) {
      w += r > 255 ? fs : fs * 0.62;
    }
    return w;
  }

  void _flushQueue(int now) {
    if (_queue.isEmpty) return;
    _syncLanes();
    final sp = max(40.0, widget.c.danmakuSpeed.value);
    for (int i = _queue.length - 1; i >= 0; i--) {
      if (now - _queue[i].born > 5000) _queue.removeAt(i);
    }
    int qi = 0;
    while (qi < _queue.length) {
      final p = _queue[qi];
      final fs = widget.c.danmakuFontSize.value;
      final text =
          '${p.m.nickname.isEmpty ? "神秘用户" : p.m.nickname}: ${p.m.content}';
      final w = _measure(text, fs);
      int lane = -1;
      for (int l = 0; l < _laneFreeAt.length; l++) {
        if (_laneFreeAt[l] <= now) {
          lane = l;
          break;
        }
      }
      if (lane < 0) break;
      _laneFreeAt[lane] = now + ((w + 32) / sp * 1000).round();
      _items.add(_FloatItem(
          text, Color(p.m.fontColor), _w, lane * _lineHeight() + 4, w));
      _queue.removeAt(qi);
    }
  }

  void _tick(Duration d) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = _lastNow == 0 ? 0.016 : (now - _lastNow) / 1000.0;
    _lastNow = now;
    if (_w <= 0) return;
    _flushQueue(now);
    if (_items.isEmpty) return;
    final sp = widget.c.danmakuSpeed.value;
    for (int i = _items.length - 1; i >= 0; i--) {
      final it = _items[i];
      it.x -= sp * dt;
      if (it.x + it.w < 0) _items.removeAt(i);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cons) {
      _w = cons.maxWidth;
      _h = cons.maxHeight;
      return IgnorePointer(
        child: Obx(() {
          if (!widget.c.showDanmaku.value) return const SizedBox.expand();
          final op = widget.c.danmakuOpacity.value;
          final fs = widget.c.danmakuFontSize.value;
          return SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final it in _items)
                  Positioned(
                    left: it.x,
                    top: it.y,
                    child: Opacity(
                      opacity: op,
                      child: Text(
                        it.text,
                        maxLines: 1,
                        style: TextStyle(
                          color: it.color,
                          fontSize: fs,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      );
    });
  }
}

// ================= 弹幕列表 =================
class _DanmakuList extends StatefulWidget {
  final LivePlayController c;
  const _DanmakuList({required this.c});
  @override
  State<_DanmakuList> createState() => _DanmakuListState();
}

class _DanmakuListState extends State<_DanmakuList> {
  final ScrollController _sc = ScrollController();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.c.danmakuList.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients && _sc.position.maxScrollExtent > 0) {
          _sc.jumpTo(_sc.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sc.dispose();
    super.dispose();
  }

  /// ★ 粉丝牌按等级分色（对齐网页版视觉）
  Color _fansColor(int lv) {
    if (lv <= 6) return const Color(0xFF59B4FF);
    if (lv <= 12) return const Color(0xFF38C3FF);
    if (lv <= 19) return const Color(0xFFFFB03A);
    if (lv <= 25) return const Color(0xFFFF6B9C);
    if (lv <= 31) return const Color(0xFFB46BFF);
    if (lv <= 40) return const Color(0xFFFF8800);
    return const Color(0xFFFF4040);
  }

  /// ★ 参考 pure_live：[表情] → 内联图片（优先全局字典，兜底内置）
  List<InlineSpan> _contentSpans(String text) {
    final spans = <InlineSpan>[];
    final reg = RegExp(r'\[([^\]]+)\]');
    var last = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final name = m.group(1) ?? '';
      final url = HuyaDanmakuClient.emoteRegistry[name] ??
          DanmakuMessage.emoteMap[name];
      if (url != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Image.network(url, width: 18, height: 18,
                errorBuilder: (_, __, ___) => Text('[$name]',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14))),
          ),
        ));
      } else {
        spans.add(TextSpan(text: '[$name]'));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Obx(() {
      if (c.danmakuList.isEmpty) {
        return Center(
            child: Text(c.danmakuStatus.value,
                style: const TextStyle(color: Colors.white24)));
      }
      final list = c.danmakuList;
      return ListView.builder(
        controller: _sc,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: list.length,
        itemBuilder: (_, i) => _item(c, list[i]),
      );
    });
  }

  Widget _item(LivePlayController c, DanmakuMessage m) {
    final fc = _fansColor(m.fansLevel);
    return GestureDetector(
      onTap: () => c.showUserInfo(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // ★ 粉丝牌：等级分色
              if (m.fansName.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        fc.withOpacity(0.30),
                        fc.withOpacity(0.12),
                      ]),
                      border: Border.all(color: fc.withOpacity(0.55)),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${m.fansLevel} ${m.fansName}',
                      style: TextStyle(
                          color: fc,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              // ★ 贵族/粉钻等装饰图
              for (final url in m.badgeUrls)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Image.network(url, width: 18, height: 18,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              // ★ 房管图
              if (m.managerType > 0 &&
                  !m.badgeUrls.any((u) => u.contains('fangguan')))
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Image.network(DanmakuMessage.kBadgeManager,
                      width: 18, height: 18,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${m.nickname.isEmpty ? "神秘用户" : m.nickname}: ',
                    style: TextStyle(
                        color: Color(m.fontColor),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                ..._contentSpans(m.content),
              ])),
            ]),
      ),
    );
  }
}

// ================= 主播详情 =================
class _DetailTab extends StatelessWidget {
  final LivePlayController c;
  const _DetailTab({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _card(),
              child: Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white10,
                  backgroundImage: c.streamerAvatar.value.isNotEmpty
                      ? NetworkImage(c.streamerAvatar.value)
                      : null,
                  child: c.streamerAvatar.value.isEmpty
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            c.streamerName.value.isEmpty
                                ? '—'
                                : c.streamerName.value,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            '房间号 ${c.roomId} · ${c.isLive.value ? "直播中" : "未开播"}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: c.isLive.value
                          ? const Color(0x33E5484D)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(c.isLive.value ? 'LIVE' : 'OFF',
                      style: TextStyle(
                          color: c.isLive.value
                              ? const Color(0xFFE5484D)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: _card(),
              child: Row(children: [
                _stat(_fmt(c.fansCount.value), '粉丝'),
                _divider(),
                _stat(_fmt(c.heatCount.value), '热度'),
                _divider(),
                _stat('${c.qualities.length} 档', '清晰度'),
              ]),
            ),
            if (c.isLive.value && c.liveDurationText.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _card(),
                child: Row(children: [
                  const Icon(Icons.schedule, color: Color(0xFF7ED97E)),
                  const SizedBox(width: 10),
                  const Text('开播时长',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Text(c.liveDurationText.value,
                      style: const TextStyle(
                          color: Color(0xFF7ED97E),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            if (!c.isLive.value && c.lastLiveText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _card(),
                child: Row(children: [
                  const Icon(Icons.history, color: Colors.white54),
                  const SizedBox(width: 10),
                  const Text('上次开播',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Text(c.lastLiveText,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                ]),
              ),
            ],
            if (c.roomTitle.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _card(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('直播预告',
                          style: TextStyle(
                              color: Color(0xFFFF8800),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(c.roomTitle.value,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
              ),
            ],
          ],
        ));
  }

  String _fmt(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  Widget _stat(String v, String label) {
    return Expanded(
      child: Column(children: [
        Text(v,
            style: const TextStyle(
                color: Color(0xFF00D2FF),
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: Colors.white12);

  BoxDecoration _card() => BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      );
}
