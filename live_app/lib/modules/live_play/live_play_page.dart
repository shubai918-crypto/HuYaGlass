import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import 'live_play_controller.dart';

List<InlineSpan> buildEmoteSpans(String text, {double fontSize = 14, Color? textColor}) {
  final spans = <InlineSpan>[];
  final reg = RegExp(r'\[([^\]]+)\]');
  var last = 0;
  for (final m in reg.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    final key = m.group(0)!;
    final url = HuyaDanmakuClient.emoteRegistry[key];
    if (url != null) {
      final big = HuyaDanmakuClient.isBigEmote(url);
      final size = big ? 64.0 : 22.0;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Image.network(url, width: size, height: size,
              errorBuilder: (_, __, ___) => Text(key,
                  style: TextStyle(color: textColor ?? Colors.white70, fontSize: fontSize))),
        ),
      ));
    } else {
      spans.add(TextSpan(text: key));
    }
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

class LivePlayPage extends StatefulWidget {
  const LivePlayPage({super.key});
  @override
  State<LivePlayPage> createState() => _LivePlayPageState();
}

class _LivePlayPageState extends State<LivePlayPage>
    with SingleTickerProviderStateMixin {
  late final LivePlayController c = Get.put(LivePlayController());
  late final TabController _tab = TabController(length: 3, vsync: this);
  bool _chromeVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _chromeVisible = true);
    });
  }

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
    return Material(
      type: MaterialType.transparency,
      child: Obx(() => c.isFullscreen.value ? _buildFullscreen() : _buildPortrait(context)),
    );
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(children: [c.videoHost(true), DanmakuOverlay(c: c)]),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Column(children: [
        SizedBox(height: top),
        GlassMaterialize(visible: _chromeVisible, child: _header()),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(children: [c.videoHost(false), DanmakuOverlay(c: c)]),
        ),
        _tabs(),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            _DanmakuList(c: c),
            _DetailTab(c: c),
            _DebugTab(c: c),
          ]),
        ),
        GlassMaterialize(visible: _chromeVisible, child: _bottomBar()),
      ]),
    );
  }

  Widget _header() {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white10,
              backgroundImage: c.streamerAvatar.value.isNotEmpty
                  ? NetworkImage(c.streamerAvatar.value) : null,
              child: c.streamerAvatar.value.isEmpty
                  ? const Icon(Icons.person, size: 20, color: Colors.white54) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.streamerName.value.isEmpty ? '—' : c.streamerName.value,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('粉丝 ${_fmt(c.fansCount.value)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _showHighEnergySheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x33FFB25E), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department, color: Color(0xFFFFB25E), size: 14),
                  SizedBox(width: 3),
                  Text('高能观众', style: TextStyle(color: Color(0xFFFFB25E), fontSize: 11)),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: c.toggleFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0x33E5484D),
                    border: Border.all(color: const Color(0xFFE5484D)),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c.isFollowed.value ? '已订阅' : '订阅',
                    style: const TextStyle(color: Color(0xFFE5484D), fontSize: 12)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ),
          ]),
        ));
  }

  void _showHighEnergySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HighEnergySheet(c: c),
    );
  }

  Widget _tabs() {
    return Container(
      color: const Color(0xFF101018),
      child: TabBar(
        controller: _tab,
        indicatorColor: const Color(0xFF00D2FF),
        labelColor: const Color(0xFF00D2FF),
        unselectedLabelColor: Colors.white54,
        tabs: const [Tab(text: '弹幕'), Tab(text: '主播详情'), Tab(text: '调试')],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: const Color(0xFF101018),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 34, child: Obx(() => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: c.qualities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final q = c.qualities[i];
                final sel = q.name == c.currentQuality.value;
                return GestureDetector(
                  onTap: () => c.switchQuality(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: sel ? const Color(0xFF00D2FF).withOpacity(0.12) : Colors.white.withOpacity(0.05),
                        border: Border.all(color: sel ? const Color(0xFF00D2FF) : Colors.white.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(14)),
                    child: Text(q.name, style: TextStyle(color: sel ? const Color(0xFF00D2FF) : Colors.white60, fontSize: 12)),
                  ),
                );
              }))),
        const SizedBox(height: 8),
        SizedBox(height: 34, child: Obx(() => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: c.lines.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = i == c.currentLine.value;
                return GestureDetector(
                  onTap: () => c.switchLine(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: sel ? const Color(0xFF00D2FF).withOpacity(0.12) : Colors.white.withOpacity(0.05),
                        border: Border.all(color: sel ? const Color(0xFF00D2FF) : Colors.white.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(14)),
                    child: Text('线路${i + 1}', style: TextStyle(color: sel ? const Color(0xFF00D2FF) : Colors.white60, fontSize: 12)),
                  ),
                );
              }))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(22)),
            child: TextField(
              controller: c.inputController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(hintText: '发送弹幕...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
              onSubmitted: (t) => c.sendDanmaku(t),
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showEmotePicker,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFFFB25E), size: 24),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => c.sendDanmaku(c.inputController.text),
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: Color(0xFF00D2FF), shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showEmotePicker() {
    final entries = HuyaDanmakuClient.emoteRegistry.entries.toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, sc) => Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Text('表情', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: GridView.builder(
            controller: sc,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final tc = c.inputController;
                  final text = tc.text;
                  final sel = tc.selection;
                  final start = sel.start.clamp(0, text.length);
                  final end = sel.end.clamp(0, text.length);
                  final insert = e.key;
                  tc.text = text.replaceRange(start, end, insert);
                  tc.selection = TextSelection.collapsed(offset: start + insert.length);
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.network(e.value, width: 40, height: 40, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  const SizedBox(height: 4),
                  Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ]),
              );
            },
          )),
        ]),
      ),
    );
  }
}

class _FloatItem { final String text; final Color color; final double w; double x; final double y; _FloatItem(this.text, this.color, this.x, this.y, this.w); }
class _PendingItem { final DanmakuMessage m; final int born; _PendingItem(this.m, this.born); }

class DanmakuOverlay extends StatefulWidget {
  final LivePlayController c;
  const DanmakuOverlay({super.key, required this.c});
  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> with SingleTickerProviderStateMixin {
  final List<_FloatItem> _items = [];
  final List<_PendingItem> _queue = [];
  final List<int> _laneFreeAt = [];
  Ticker? _ticker; StreamSubscription? _sub;
  int _lastNow = 0; double _w = 0; double _h = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _sub = widget.c.danmakuList.listen((_) {
      if (widget.c.danmakuList.isNotEmpty) {
        final m = widget.c.danmakuList.last;
        if (m.isHistory) return;
        if (m.isGift && !widget.c.showGiftOverlay.value) return;
        _enqueue(m);
      }
    });
  }

  @override
  void dispose() { _ticker?.dispose(); _sub?.cancel(); super.dispose(); }

  double _lineHeight() => widget.c.danmakuFontSize.value * 1.8;
  void _syncLanes() {
    final n = max(1, (_h * widget.c.danmakuArea.value / _lineHeight()).floor());
    if (_laneFreeAt.length != n) { _laneFreeAt.clear(); _laneFreeAt.addAll(List.filled(n, 0)); }
  }
  void _enqueue(DanmakuMessage m) {
    if (!widget.c.showDanmaku.value || _w <= 0 || _h <= 0) return;
    if (_queue.length > 40) _queue.removeAt(0);
    _queue.add(_PendingItem(m, DateTime.now().millisecondsSinceEpoch));
  }
  double _measure(String text, double fs) { double w = 8; for (final r in text.runes) w += r > 255 ? fs : fs * 0.62; return w; }

  void _flushQueue(int now) {
    if (_queue.isEmpty) return;
    _syncLanes();
    final sp = max(40.0, widget.c.danmakuSpeed.value);
    for (int i = _queue.length - 1; i >= 0; i--) if (now - _queue[i].born > 5000) _queue.removeAt(i);
    int qi = 0;
    while (qi < _queue.length) {
      final p = _queue[qi];
      final fs = widget.c.danmakuFontSize.value;
      final text = '${p.m.nickname.isEmpty ? "神秘用户" : p.m.nickname}: ${p.m.content}';
      final w = _measure(text, fs);
      int lane = -1;
      for (int l = 0; l < _laneFreeAt.length; l++) if (_laneFreeAt[l] <= now) { lane = l; break; }
      if (lane < 0) break;
      _laneFreeAt[lane] = now + ((w + 32) / sp * 1000).round();
      _items.add(_FloatItem(text, Color(p.m.fontColor), _w, lane * _lineHeight() + 4, w));
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
    for (int i = _items.length - 1; i >= 0; i--) { final it = _items[i]; it.x -= sp * dt; if (it.x + it.w < 0) _items.removeAt(i); }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cons) {
      _w = cons.maxWidth; _h = cons.maxHeight;
      return IgnorePointer(child: Obx(() {
        if (!widget.c.showDanmaku.value) return const SizedBox.expand();
        final op = widget.c.danmakuOpacity.value;
        final fs = widget.c.danmakuFontSize.value;
        return SizedBox.expand(child: Stack(clipBehavior: Clip.hardEdge, children: [
          for (final it in _items)
            Positioned(left: it.x, top: it.y, child: Opacity(
              opacity: op,
              child: Text.rich(
                TextSpan(children: buildEmoteSpans(it.text, fontSize: fs, textColor: Color(it.fontColor))),
                maxLines: 1,
                style: TextStyle(
                    color: Color(it.fontColor),   // ★ 用消息自带颜色，不再写死白色
                    fontSize: fs,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 3)]),
              ),
            )),
        ]));
      }));
    });
  }
}

class _DanmakuList extends StatefulWidget {
  final LivePlayController c;
  const _DanmakuList({required this.c});
  @override
  State<_DanmakuList> createState() => _DanmakuListState();
}

class _DanmakuListState extends State<_DanmakuList> {
  final ScrollController _sc = ScrollController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Color _fansColor(int lv) {
    if (lv <= 6) return const Color(0xFF59B4FF);
    if (lv <= 12) return const Color(0xFF38C3FF);
    if (lv <= 19) return const Color(0xFFFFB03A);
    if (lv <= 25) return const Color(0xFFFF6B9C);
    if (lv <= 31) return const Color(0xFFB46BFF);
    if (lv <= 40) return const Color(0xFFFF8800);
    return const Color(0xFFFF4040);
  }

  /// 点击弹幕：可自由复制 + "+1 复读"（纸飞机发送）
  void _showDanmakuActions(LivePlayController c, DanmakuMessage m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            SelectableText(
              m.isGift ? '${m.nickname} 送 ${m.giftName}' : m.content,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text('${m.nickname} · UID: ${m.uid > 0 ? '${m.uid}' : '未知'}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: m.isGift ? '${m.nickname} 送 ${m.giftName}' : m.content));
                  Get.back();
                  Get.snackbar('提示', '已复制到剪贴板',
                      backgroundColor: const Color(0xFF1A1A2E),
                      colorText: Colors.white70,
                      snackPosition: SnackPosition.BOTTOM);
                },
                icon: const Icon(Icons.copy, size: 18, color: Color(0xFF00D2FF)),
                label: const Text('复制', style: TextStyle(color: Color(0xFF00D2FF))),
              )),
              const SizedBox(width: 12),
              if (!m.isGift)
                Expanded(child: TextButton.icon(
                  onPressed: () {
                    Get.back();
                    c.sendDanmaku(m.content);
                  },
                  icon: const Icon(Icons.send, size: 18, color: Color(0xFFFF8800)),
                  label: const Text('+1 复读', style: TextStyle(color: Color(0xFFFF8800))),
                )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showDanmakuSettings(LivePlayController c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('弹幕设置',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            Obx(() => ListTile(
                  title: const Text('飘屏显示礼物弹幕',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Switch(
                    value: c.showGiftOverlay.value,
                    onChanged: (v) => c.showGiftOverlay.value = v,
                  ),
                )),
            Obx(() => ListTile(
                  title: const Text('列表显示礼物弹幕',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Switch(
                    value: c.showGiftList.value,
                    onChanged: (v) => c.showGiftList.value = v,
                  ),
                )),
          ]),
        ),
      ),
    );
  }

  Widget _item(LivePlayController c, DanmakuMessage m) {
    if (m.isGift) {
      final icon = DanmakuMessage.kGiftIcons[m.giftName];
      final fc = _fansColor(m.fansLevel);
      return GestureDetector(
        onTap: () => _showDanmakuActions(c, m),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (m.fansName.isNotEmpty)
              Container(margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [fc.withOpacity(0.3), fc.withOpacity(0.12)]),
                      border: Border.all(color: fc.withOpacity(0.55)),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${m.fansLevel} ${m.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
            Text('${m.nickname}: ', style: const TextStyle(color: Color(0xFFFFB25E), fontSize: 14, fontWeight: FontWeight.w600)),
            const Text('送 ', style: TextStyle(color: Colors.white70, fontSize: 14)),
            if (icon != null)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Image.network(icon, width: 20, height: 20, errorBuilder: (_, __, ___) => Text(m.giftName, style: const TextStyle(color: Colors.white70, fontSize: 14))))
            else
              Text(m.giftName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(' ${m.giftCount}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            if (m.comboCount > 1) Text(' ${m.comboCount}连击', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
      );
    }
    final fc = _fansColor(m.fansLevel);
    final guard = c.client.guardList.isNotEmpty
        ? c.client.guardList.firstWhereOrNull((g) => g.nickname == m.nickname) : null;
    final shownBadges = <String>[];
    bool mgrShown = false;
    for (final u in m.badgeUrls) {
      final isMgr = u.contains('fangguan') || u.contains('manager');
      if (isMgr) { if (mgrShown) continue; mgrShown = true; }
      shownBadges.add(u);
    }
    if (m.managerType > 0 && !mgrShown) shownBadges.add(DanmakuMessage.kBadgeManager);
    return GestureDetector(
      onTap: () => _showDanmakuActions(c, m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (m.fansName.isNotEmpty)
            Container(margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [fc.withOpacity(0.3), fc.withOpacity(0.12)]),
                    border: Border.all(color: fc.withOpacity(0.55)),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${m.fansLevel} ${m.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
          if (guard != null && guard.guardIcon.isNotEmpty)
            Padding(padding: const EdgeInsets.only(right: 4), child: Image.network(guard.guardIcon, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          for (final url in shownBadges)
            Padding(padding: const EdgeInsets.only(right: 4), child: Image.network(url, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          Text.rich(TextSpan(children: [
            TextSpan(text: '${m.nickname.isEmpty ? "神秘用户" : m.nickname}: ',
                style: TextStyle(color: Color(m.fontColor), fontSize: 14, fontWeight: FontWeight.w600)),
            ...buildEmoteSpans(m.content),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Obx(() {
      final list = c.danmakuList
          .where((m) => !m.isGift || c.showGiftList.value)
          .toList();
      if (list.isEmpty) {
        return Center(child: Text(c.danmakuStatus.value, style: const TextStyle(color: Colors.white24)));
      }
      return Stack(children: [
        GlassScrollEdgeEffect(
          style: GlassScrollEdgeStyle.soft,
          child: Scrollbar(
            controller: _sc, thumbVisibility: true, thickness: 4, radius: const Radius.circular(4),
            child: ListView.builder(
              controller: _sc,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: list.length,
              itemBuilder: (_, i) => _item(c, list[i]),
            ),
          ),
        ),
        Positioned(right: 6, bottom: 12, child: Column(children: [
          GlassIconButton(icon: const Icon(Icons.tune, color: Colors.white), size: 40,
              onPressed: () => _showDanmakuSettings(c)),
          const SizedBox(height: 8),
          GlassIconButton(icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white), size: 40,
              onPressed: () => _sc.hasClients ? _sc.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null),
          const SizedBox(height: 8),
          GlassIconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white), size: 40,
              onPressed: () => _sc.hasClients ? _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null),
        ])),
      ]);
    });
  }
}

class _HighEnergySheet extends StatefulWidget {
  final LivePlayController c;
  const _HighEnergySheet({required this.c});
  @override
  State<_HighEnergySheet> createState() => _HighEnergySheetState();
}

class _HighEnergySheetState extends State<_HighEnergySheet> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<VipUser> _guard = [];
  List<VipUser> _vip = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _sync();
    _sub = widget.c.client.vipStream.listen((_) { if (mounted) setState(_sync); });
  }

  void _sync() {
    _guard = List.from(widget.c.client.guardList);
    _vip = List.from(widget.c.client.vipList);
  }

  @override
  void dispose() { _sub?.cancel(); _tab.dispose(); super.dispose(); }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return Colors.white38;
    }
  }

  Color _fansColor(int lv) {
    if (lv <= 6) return const Color(0xFF59B4FF);
    if (lv <= 12) return const Color(0xFF38C3FF);
    if (lv <= 19) return const Color(0xFFFFB03A);
    if (lv <= 25) return const Color(0xFFFF6B9C);
    if (lv <= 31) return const Color(0xFFB46BFF);
    if (lv <= 40) return const Color(0xFFFF8800);
    return const Color(0xFFFF4040);
  }

  String _guardIconUrl(int lv) =>
      'https://diy-assets.msstatic.com/hyys/guardgrade202211/guardrank/$lv.png';
  bool _isGuardTitle(String s) => s == '剑士' || s == '骑士' || s == '领主';
  Widget _img(String url) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Image.network(url, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      );

  Widget _row(VipUser u, int index) {
    final fc = _fansColor(u.fansLevel);
    final gIcon = u.guardIcon.isNotEmpty ? u.guardIcon : (u.guardLevel > 0 ? _guardIconUrl(u.guardLevel) : '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 30, child: Text('${index + 1}', textAlign: TextAlign.center,
            style: TextStyle(color: _rankColor(index + 1), fontSize: 15, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        CircleAvatar(radius: 22, backgroundColor: const Color(0xFF2A2A34),
            backgroundImage: u.avatar.isNotEmpty ? NetworkImage(u.avatar) : null,
            child: u.avatar.isEmpty ? const Icon(Icons.person, size: 22, color: Colors.white38) : null),
        const SizedBox(width: 10),
        if (u.fansName.isNotEmpty && !_isGuardTitle(u.fansName))
          Container(margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [fc.withOpacity(0.3), fc.withOpacity(0.12)]),
                  border: Border.all(color: fc.withOpacity(0.55)),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${u.fansLevel} ${u.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
        if (gIcon.isNotEmpty) _img(gIcon),
        if (u.nobleIcon.isNotEmpty) _img(u.nobleIcon),
        if (u.managerType > 0) _img(DanmakuMessage.kBadgeManager),
        Expanded(child: Text(u.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
    );
  }

  Widget _list(List<VipUser> users, String emptyText) {
    if (users.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.white38, fontSize: 13)));
    }
    return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: users.length,
        itemBuilder: (_, i) => _row(users[i], i));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.55;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: height,
        color: const Color(0xFF14141C),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          TabBar(controller: _tab,
              labelColor: const Color(0xFF00D2FF),
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFF00D2FF),
              tabs: [Tab(text: '守护 (${_guard.length})'), Tab(text: '贵宾 (${_vip.length})')]),
          Expanded(child: TabBarView(controller: _tab, children: [
            _list(_guard, '暂无守护'),
            _list(_vip, '暂无贵宾'),
          ])),
        ]),
      ),
    );
  }
}

class _DetailTab extends StatelessWidget {
  final LivePlayController c;
  const _DetailTab({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(padding: const EdgeInsets.all(12), children: [
      Container(padding: const EdgeInsets.all(12), decoration: _card(), child: Row(children: [
        CircleAvatar(radius: 26, backgroundColor: Colors.white10,
            backgroundImage: c.streamerAvatar.value.isNotEmpty ? NetworkImage(c.streamerAvatar.value) : null,
            child: c.streamerAvatar.value.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.streamerName.value.isEmpty ? '—' : c.streamerName.value,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('房间号 ${c.roomId} · ${c.isLive.value ? "直播中" : "未开播"}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: c.isLive.value ? const Color(0x33E5484D) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Text(c.isLive.value ? 'LIVE' : 'OFF',
                style: TextStyle(color: c.isLive.value ? const Color(0xFFE5484D) : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700))),
      ])),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: _card(),
          child: Row(children: [
            _stat(_fmt(c.fansCount.value), '粉丝'), _divider(),
            _stat(_fmt(c.heatCount.value), '热度'), _divider(),
            _stat('${c.qualities.length} 档', '清晰度'),
          ])),
      if (c.isLive.value && c.liveDurationText.value.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(), child: Row(children: [
          const Icon(Icons.schedule, color: Color(0xFF7ED97E)),
          const SizedBox(width: 10),
          const Text('开播时长', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          Text(c.liveDurationText.value, style: const TextStyle(color: Color(0xFF7ED97E), fontSize: 15, fontWeight: FontWeight.w700)),
        ])),
      ],
      if (!c.isLive.value && c.lastLiveText.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(), child: Row(children: [
          const Icon(Icons.history, color: Colors.white54),
          const SizedBox(width: 10),
          const Text('上次开播', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          Text(c.lastLiveText, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ])),
      ],
      if (c.roomTitle.value.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('直播预告', style: TextStyle(color: Color(0xFFFF8800), fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(c.roomTitle.value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
      ],
    ]));
  }

  String _fmt(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }
  Widget _stat(String v, String label) => Expanded(child: Column(children: [
        Text(v, style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]));
  Widget _divider() => Container(width: 1, height: 30, color: Colors.white12);
  BoxDecoration _card() => BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06)));
}

class _DebugTab extends StatelessWidget {
  final LivePlayController c;
  const _DebugTab({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(padding: const EdgeInsets.all(12), children: [
      const Text('协议调试日志', style: TextStyle(color: Color(0xFF00D2FF), fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SelectableText(c.debugInfo.value.isEmpty ? '（暂无日志）' : c.debugInfo.value,
          style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.7)),
      const SizedBox(height: 12),
      Text('状态：${c.danmakuStatus.value}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ]));
  }
}
