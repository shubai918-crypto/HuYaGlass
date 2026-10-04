import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/app_settings.dart';
import '../home/home_page.dart';
import 'live_play_controller.dart';

List<InlineSpan> buildEmoteSpans(String text, {double fontSize = 14, Color? textColor}) {
  final spans = <InlineSpan>[]; final reg = RegExp(r'\[([^\]]+)\]'); var last = 0;
  for (final m in reg.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    final key = m.group(0)!; final url = HuyaDanmakuClient.emoteRegistry[key];
    if (url != null) {
      final size = HuyaDanmakuClient.isBigEmote(url) ? 64.0 : 22.0;
      spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Image.network(url, width: size, height: size,
                  errorBuilder: (_, __, ___) => Text(key, style: TextStyle(color: textColor ?? const Color(0xFF23272E), fontSize: fontSize))))));
    } else { spans.add(TextSpan(text: key)); }
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

class _LivePlayPageState extends State<LivePlayPage> with SingleTickerProviderStateMixin {
  late final LivePlayController c = Get.put(LivePlayController());
  late final TabController _tab = TabController(length: 3, vsync: this);
  bool _chromeVisible = false;
  Worker? _nameWorker;
  Worker? _avatarWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _chromeVisible = true); });
    final args = Get.arguments;
    final roomId = (args is Map ? args['roomId'] : null)?.toString() ?? '';
    _nameWorker = ever(c.streamerName, (name) {
      if (name.isNotEmpty) {
        NowWatching.notifier.value = NowRoom(roomId: roomId, nickname: name, avatarUrl: c.streamerAvatar.value);
      }
    });
    _avatarWorker = ever(c.streamerAvatar, (av) {
      final cur = NowWatching.notifier.value;
      if (av.isNotEmpty && cur != null && cur.roomId == roomId) {
        NowWatching.notifier.value = NowRoom(roomId: roomId, nickname: cur.nickname, avatarUrl: av);
      }
    });
  }

  @override
  void dispose() {
    _nameWorker?.dispose();
    _avatarWorker?.dispose();
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
    return Material(type: MaterialType.transparency, child: Obx(() => c.isFullscreen.value ? _buildFullscreen() : _buildPortrait(context)));
  }

  Widget _buildFullscreen() => Scaffold(backgroundColor: Colors.black, body: SizedBox.expand(child: Stack(children: [c.videoHost(true), DanmakuOverlay(c: c)])));

  Widget _buildPortrait(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: false,
      body: Column(children: [
        SizedBox(height: top),
        GlassMaterialize(visible: _chromeVisible, child: _header()),
        AspectRatio(aspectRatio: 16 / 9, child: Stack(children: [c.videoHost(false), DanmakuOverlay(c: c)])),
        _tabs(),
        Expanded(child: TabBarView(controller: _tab, children: [
          _DanmakuList(c: c), _DetailTab(c: c), _DebugTab(c: c),
        ])),
        GlassMaterialize(visible: _chromeVisible, child: _bottomBar()),
      ]),
    );
  }

  // 头部悬浮在视频上，保持深色玻璃（对比度最好）
  Widget _header() {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: GlassContainer(
            shape: const LiquidRoundedSuperellipse(borderRadius: 24),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            useOwnLayer: true, quality: GlassQuality.premium,
            settings: LiquidGlassSettings(
              blur: 15, thickness: 30, refractiveIndex: 1.2, saturation: 1.3,
              glassColor: Colors.black.withOpacity(0.15),
              platformViewMode: PlatformViewGlassMode.passthrough,
              bodyMode: GlassBodyMode.adaptive,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                CircleAvatar(radius: 18, backgroundColor: Colors.white10,
                    backgroundImage: c.streamerAvatar.value.isNotEmpty ? NetworkImage(c.streamerAvatar.value) : null,
                    child: c.streamerAvatar.value.isEmpty ? const Icon(Icons.person, size: 18, color: Colors.white54) : null),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(c.streamerName.value.isEmpty ? '—' : c.streamerName.value,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.1, shadows: [Shadow(color: Colors.black54, blurRadius: 2)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('粉丝 ${_fmt(c.fansCount.value)}', style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                GestureDetector(
                  onTap: _showHighEnergySheet,
                  child: GlassContainer(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 999),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    settings: LiquidGlassSettings(blur: 8, thickness: 16, glassColor: const Color(0x55FFB25E)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_fire_department, color: Color(0xFFFFB25E), size: 12),
                      SizedBox(width: 3),
                      Text('高能', style: TextStyle(color: Color(0xFFFFB25E), fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: c.toggleFollow,
                  child: GlassContainer(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 999),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    settings: LiquidGlassSettings(blur: 8, thickness: 16,
                        glassColor: c.isFollowed.value ? Colors.white.withOpacity(0.10) : const Color(0x66E5484D)),
                    child: Text(c.isFollowed.value ? '已订阅' : '订阅', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const Spacer(),
                GlassPullDownButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                  items: [
                    GlassMenuItem(title: '复制房间链接', onTap: _copyUrl),
                    GlassMenuItem(title: '刷新线路', onTap: c.refreshPlay),
                    GlassMenuItem(title: c.isMuted.value ? '取消静音' : '静音', onTap: c.toggleMute),
                    GlassMenuItem(title: c.isFullscreen.value ? '退出全屏' : '全屏', onTap: c.toggleFullscreen),
                  ],
                ),
              ]),
            ]),
          ),
        ));
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: 'https://www.huya.com/${c.roomId}'));
    Get.snackbar('已复制', '房间链接已复制到剪贴板', snackPosition: SnackPosition.BOTTOM);
  }

  void _showHighEnergySheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _LightSheet(child: _HighEnergyBody(c: c)),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 999),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        useOwnLayer: true,
        quality: GlassQuality.premium,
        settings: _lightGlass(),
        child: TabBar(
          controller: _tab,
          indicatorColor: kAccent,
          labelColor: kAccent,
          unselectedLabelColor: const Color(0xFF5F6672),
          tabs: const [Tab(text: '弹幕'), Tab(text: '主播详情'), Tab(text: '调试')],
        ),
      ),
    );
  }

  // ★ 浅色通透玻璃 + 加强拖拽镜面光感
  LiquidGlassSettings _lightGlass() => LiquidGlassSettings(
        glassColor: const Color(0xB3FFFFFF),
        thickness: 26,
        blur: 14,
        lightIntensity: 0.6,
        specularSharpness: GlassSpecularSharpness.medium,
        fresnelStrength: 1.0,
        refractiveIndex: 1.15,
        saturation: 1.3,
        chromaticAberration: 0.012,
      );

  // ★ 底栏：左 pill + 右四键组（发送并入组内，红色大圆钮已删除）
  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(children: [
        Expanded(
          child: GlassButton.custom(
            onTap: () => _openComposeSheet(),
            height: 48,
            useOwnLayer: true,
            quality: GlassQuality.premium,
            shape: const LiquidRoundedSuperellipse(borderRadius: 24),
            settings: _lightGlass(),
            stretch: 0.5,
            resistance: 0.08,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Icon(Icons.edit_note, color: Color(0xFF8A9099), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: c.inputController,
                    builder: (context, v, _) => Text(
                      v.text.isEmpty ? '发弹幕...' : v.text,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: v.text.isEmpty ? const Color(0xFFA6ADB5) : const Color(0xFF3C4248), fontSize: 13),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GlassButtonGroup.icons(
          useOwnLayer: true,
          quality: GlassQuality.premium,
          borderRadius: 24,
          iconSize: 20,
          itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          settings: _lightGlass(),
          items: [
            GlassButtonGroupItem(label: '清晰度', icon: const Icon(Icons.speed, color: Color(0xFF3C4248)), onTap: _openQualitySheet),
            GlassButtonGroupItem(label: '弹幕设置', icon: const Icon(Icons.tune, color: Color(0xFF3C4248)), onTap: _showDanmakuSettingsSheet),
            GlassButtonGroupItem(label: '表情', icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF3C4248)), onTap: () => _openComposeSheet(focusEmoji: true)),
            GlassButtonGroupItem(label: '发送', icon: const Icon(Icons.send, color: kAccent), onTap: () => _openComposeSheet()),
          ],
        ),
      ]),
    );
  }

  // ★ 修复 Bug：改回酷安同款实色白 Sheet（内容多高 Sheet 多高，拖拽关闭原生接管，零重影）
  void _openQualitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LightSheet(child: _qualityContent()),
    );
  }

  void _openComposeSheet({bool focusEmoji = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LightSheet(child: _DanmakuComposeBody(c: c, showEmojiInitial: focusEmoji)),
    );
  }

  Widget _qualityContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.high_quality_outlined, color: Color(0xFF00B8D4), size: 16),
        const SizedBox(width: 6),
        const Text('清晰度', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, color: Color(0xFFA6ADB5), size: 18)),
      ]),
      const SizedBox(height: 12),
      Obx(() => Wrap(spacing: 10, runSpacing: 10, children: [
            for (final q in c.qualities)
              _chip(q.name, q.name == c.currentQuality.value, const Color(0xFF00B8D4), () => c.switchQuality(q)),
          ])),
      const SizedBox(height: 18),
      const Row(children: [
        Icon(Icons.route_outlined, color: kAccent, size: 16),
        SizedBox(width: 6),
        Text('线路', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Obx(() => Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < c.lines.length; i++)
              _chip('线路${i + 1}', i == c.currentLine.value, kAccent, () => c.switchLine(i)),
          ])),
    ]);
  }

  Widget _chip(String label, bool selected, Color tint, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? tint.withOpacity(0.10) : const Color(0xFFF2F3F5),
          border: Border.all(color: selected ? tint : Colors.transparent, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[Icon(Icons.check, size: 12, color: tint), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: selected ? tint : const Color(0xFF3C4248), fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  void _showDanmakuSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('弹幕设置', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700))),
            ),
            Obx(() => ListTile(
                  title: const Text('飘屏显示礼物弹幕', style: TextStyle(color: kText, fontSize: 14)),
                  trailing: Switch(value: c.showGiftOverlay.value, activeColor: kAccent, onChanged: (v) => c.showGiftOverlay.value = v),
                )),
            Obx(() => ListTile(
                  title: const Text('列表显示礼物弹幕', style: TextStyle(color: kText, fontSize: 14)),
                  trailing: Switch(value: c.showGiftList.value, activeColor: kAccent, onChanged: (v) => c.showGiftList.value = v),
                )),
          ]),
        ),
      ),
    );
  }
}

// ★ 酷安同款实色白 Sheet 外壳（grabber + 内容自适应高度 + 底部安全区）
class _LightSheet extends StatelessWidget {
  final Widget child;
  const _LightSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: const Color(0xFFD8DBE0), borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: child),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 评论 Sheet 内容（浅色 + 富文本输入 + 智能退格 + 表情/短语面板）
// ─────────────────────────────────────────────────────────────────────────────
class _DanmakuComposeBody extends StatefulWidget {
  final LivePlayController c;
  final bool showEmojiInitial;
  const _DanmakuComposeBody({required this.c, this.showEmojiInitial = false});
  @override
  State<_DanmakuComposeBody> createState() => _DanmakuComposeBodyState();
}

class _DanmakuComposeBodyState extends State<_DanmakuComposeBody> {
  final FocusNode _fn = FocusNode();
  bool _emojiOpen = false;
  bool _phraseOpen = false;
  bool _sending = false;

  static const List<String> _kPhrases = [
    '666666', '主播帅呆了！', '来了来了', '加油加油！', '哈哈哈哈',
    '这波操作可以', '注意身体别熬夜', '求带飞', '弹幕护体', '前排围观',
  ];

  @override
  void initState() {
    super.initState();
    _emojiOpen = widget.showEmojiInitial;
    _fn.addListener(_onFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_emojiOpen && !_phraseOpen) _fn.requestFocus();
    });
  }

  void _onFocus() {
    if (_fn.hasFocus && (_emojiOpen || _phraseOpen)) {
      setState(() { _emojiOpen = false; _phraseOpen = false; });
    }
  }

  @override
  void dispose() { _fn.removeListener(_onFocus); _fn.dispose(); super.dispose(); }

  void _toggleEmoji() {
    setState(() { _emojiOpen = !_emojiOpen; if (_emojiOpen) { _phraseOpen = false; _fn.unfocus(); } });
  }

  void _togglePhrase() {
    setState(() { _phraseOpen = !_phraseOpen; if (_phraseOpen) { _emojiOpen = false; _fn.unfocus(); } });
  }

  void _insert(String s) {
    final tc = widget.c.inputController;
    final text = tc.text; final sel = tc.selection;
    final start = sel.start.clamp(0, text.length); final end = sel.end.clamp(0, text.length);
    tc.text = text.replaceRange(start, end, s);
    tc.selection = TextSelection.collapsed(offset: start + s.length);
    setState(() {});
  }

  void _backspace() {
    final tc = widget.c.inputController;
    final text = tc.text;
    if (text.isEmpty) return;
    final sel = tc.selection;
    int start = sel.start < 0 ? text.length : sel.start;
    int end = sel.end < 0 ? text.length : sel.end;
    if (start == end && start > 0) {
      final prefix = text.substring(0, start);
      final m = RegExp(r'\[[^\]]+\]$').firstMatch(prefix);
      if (m != null) {
        start -= m.group(0)!.length;
      } else {
        int del = 1;
        if (start >= 2) {
          final high = text.codeUnitAt(start - 2);
          final low = text.codeUnitAt(start - 1);
          if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) del = 2;
        }
        start -= del;
      }
    } else if (start > end) {
      final t = start; start = end; end = t;
    }
    tc.text = text.replaceRange(start, end, '');
    tc.selection = TextSelection.collapsed(offset: start);
    setState(() {});
  }

  Future<void> _sendFlow() async {
    final t = widget.c.inputController.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    _fn.unfocus();
    final nav = Navigator.of(context);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const _SendingCard());
    try {
      widget.c.sendDanmaku(t);
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {}
    if (mounted) nav.pop();
    if (mounted) {
      _toast('发送成功');
      widget.c.inputController.clear();
      nav.pop();
    }
  }

  void _toast(String msg) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xE6262626), borderRadius: BorderRadius.circular(999)),
            child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1200), () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    final entries = HuyaDanmakuClient.emoteRegistry.entries.toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Opacity(
        opacity: 0,
        child: SizedBox(
          height: 1,
          child: TextField(
            controller: widget.c.inputController,
            focusNode: _fn,
            showCursor: false,
            maxLines: 1,
            textInputAction: TextInputAction.send,
            keyboardAppearance: Brightness.light,
            onSubmitted: (_) => _sendFlow(),
          ),
        ),
      ),
      GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(_fn),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(16)),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.c.inputController,
            builder: (context, v, _) => v.text.isEmpty
                ? const Align(alignment: Alignment.centerLeft,
                    child: Text('发送弹幕...', style: TextStyle(color: Color(0xFFA6ADB5), fontSize: 15)))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(children: buildEmoteSpans(v.text, fontSize: 16, textColor: const Color(0xFF23272E))),
                      style: const TextStyle(color: Color(0xFF23272E), fontSize: 16, height: 1.5),
                    ),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        IconButton(icon: Icon(Icons.emoji_emotions_outlined, color: _emojiOpen ? kAccent : const Color(0xFF576066), size: 22), onPressed: _toggleEmoji),
        IconButton(icon: Icon(Icons.add_circle_outline, color: _phraseOpen ? kAccent : const Color(0xFF576066), size: 22), onPressed: _togglePhrase),
        IconButton(icon: const Icon(Icons.backspace_outlined, color: Color(0xFF576066), size: 22), onPressed: _backspace),
        IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF576066), size: 22),
            onPressed: () { widget.c.inputController.clear(); setState(() {}); }),
        const Spacer(),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.c.inputController,
          builder: (context, v, _) {
            final can = v.text.trim().isNotEmpty && !_sending;
            return GestureDetector(
              onTap: can ? _sendFlow : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: can ? kAccent : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('发布', style: TextStyle(color: can ? Colors.white : const Color(0xFFA6ADB5), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            );
          },
        ),
      ]),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _emojiOpen ? _emoteGrid(entries) : _phraseOpen ? _phraseGrid() : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _emoteGrid(List<MapEntry<String, String>> entries) {
    return SizedBox(
      height: 220,
      child: Stack(children: [
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(0, 6, 48, 28),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final e = entries[i];
            return GestureDetector(
              onTap: () => _insert(e.key),
              child: Image.network(e.value, width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            );
          },
        ),
        Positioned(
          right: 0, bottom: 0,
          child: GestureDetector(
            onTap: _backspace,
            child: Container(
              width: 44, height: 32,
              decoration: BoxDecoration(color: const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.backspace_outlined, color: Color(0xFF576066), size: 18),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _phraseGrid() {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 5),
        itemCount: _kPhrases.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _insert(_kPhrases[i]),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(999)),
            child: Text(_kPhrases[i], style: const TextStyle(color: Color(0xFF3C4248), fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

class _SendingCard extends StatelessWidget {
  const _SendingCard();
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: 150, height: 130,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: kAccent)),
            SizedBox(height: 12),
            Text('正在发送...', style: TextStyle(color: Color(0xFF3C4248), fontSize: 13)),
          ]),
        ),
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
  final Map<String, int> _recentEnqueue = {};
  DanmakuMessage? _lastSeen;
  Ticker? _ticker; StreamSubscription? _sub;
  int _lastNow = 0; double _w = 0; double _h = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _sub = widget.c.danmakuList.listen((_) {
      final list = widget.c.danmakuList;
      if (list.isEmpty) return;
      final m = list.last;
      if (identical(m, _lastSeen)) return;
      _lastSeen = m;
      if (m.isHistory) return;
      if (m.isGift && !widget.c.showGiftOverlay.value) return;
      _enqueue(m);
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
    final key = '${m.nickname}|${m.content}'; final now = DateTime.now().millisecondsSinceEpoch;
    _recentEnqueue.removeWhere((k, t) => now - t > 5000);
    if (_recentEnqueue.containsKey(key)) return;
    _recentEnqueue[key] = now;
    if (_queue.length > 40) _queue.removeAt(0);
    _queue.add(_PendingItem(m, now));
  }

  double _measure(String text, double fs) { double w = 8; for (final r in text.runes) w += r > 255 ? fs : fs * 0.62; return w; }

  void _flushQueue(int now) {
    if (_queue.isEmpty) return;
    _syncLanes();
    final sp = max(40.0, widget.c.danmakuSpeed.value);
    for (int i = _queue.length - 1; i >= 0; i--) if (now - _queue[i].born > 5000) _queue.removeAt(i);
    int qi = 0;
    while (qi < _queue.length) {
      final p = _queue[qi]; final fs = widget.c.danmakuFontSize.value;
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
        final op = widget.c.danmakuOpacity.value; final fs = widget.c.danmakuFontSize.value;
        return SizedBox.expand(child: Stack(clipBehavior: Clip.hardEdge, children: [
          for (final it in _items)
            Positioned(left: it.x, top: it.y, child: Opacity(opacity: op,
                child: Text.rich(TextSpan(children: buildEmoteSpans(it.text, fontSize: fs, textColor: it.color)), maxLines: 1,
                    style: TextStyle(color: it.color, fontSize: fs, fontWeight: FontWeight.w600, shadows: const [Shadow(color: Colors.black87, blurRadius: 3)])))),
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
  void dispose() { _sc.dispose(); super.dispose(); }

  Color _fansColor(int lv) {
    if (lv <= 6) return const Color(0xFF2E9BF5);
    if (lv <= 12) return const Color(0xFF00B8D4);
    if (lv <= 19) return const Color(0xFFE09300);
    if (lv <= 25) return const Color(0xFFE05586);
    if (lv <= 31) return const Color(0xFF9A4FE0);
    if (lv <= 40) return const Color(0xFFFF8800);
    return const Color(0xFFE5484D);
  }

  void _showDanmakuActions(LivePlayController c, DanmakuMessage m) {
    final content = m.isGift ? '${m.nickname} 送 ${m.giftName}' : m.content;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFD8DBE0), borderRadius: BorderRadius.circular(2))),
              SelectableText(content, style: const TextStyle(color: kText, fontSize: 15, height: 1.5)),
              const SizedBox(height: 8),
              Text('${m.nickname} · UID: ${m.uid > 0 ? '${m.uid}' : '未知'}', style: const TextStyle(color: kSub, fontSize: 12)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    Get.back();
                    Get.snackbar('提示', '已复制到剪贴板', snackPosition: SnackPosition.BOTTOM);
                  },
                  icon: const Icon(Icons.copy, size: 18, color: Color(0xFF00B8D4)),
                  label: const Text('复制', style: TextStyle(color: Color(0xFF00B8D4))),
                )),
                const SizedBox(width: 12),
                if (!m.isGift)
                  Expanded(child: TextButton.icon(
                    onPressed: () { Get.back(); c.sendDanmaku(m.content); },
                    icon: const Icon(Icons.send, size: 18, color: kAccent),
                    label: const Text('+1 复读', style: TextStyle(color: kAccent)),
                  )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(LivePlayController c, DanmakuMessage m) {
    if (m.isGift) {
      final icon = DanmakuMessage.kGiftIcons[m.giftName]; final fc = _fansColor(m.fansLevel);
      return GestureDetector(onTap: () => _showDanmakuActions(c, m),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (m.fansName.isNotEmpty)
                  Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [fc.withOpacity(0.18), fc.withOpacity(0.08)]), border: Border.all(color: fc.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
                      child: Text('${m.fansLevel} ${m.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
                Text('${m.nickname}: ', style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 14, fontWeight: FontWeight.w600)),
                const Text('送 ', style: TextStyle(color: Color(0xFF576066), fontSize: 14)),
                if (icon != null)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Image.network(icon, width: 20, height: 20, errorBuilder: (_, __, ___) => Text(m.giftName, style: const TextStyle(color: Color(0xFF576066), fontSize: 14))))
                else
                  Text(m.giftName, style: const TextStyle(color: Color(0xFF576066), fontSize: 14)),
                Text(' ${m.giftCount}', style: const TextStyle(color: Color(0xFF576066), fontSize: 14)),
                if (m.comboCount > 1) Text(' ${m.comboCount}连击', style: const TextStyle(color: Color(0xFF8A9099), fontSize: 12)),
              ])));
    }
    final fc = _fansColor(m.fansLevel);
    final guard = c.client.guardList.isNotEmpty ? c.client.guardList.firstWhereOrNull((g) => g.nickname == m.nickname) : null;
    final shownBadges = <String>[]; bool mgrShown = false;
    for (final u in m.badgeUrls) {
      final isMgr = u.contains('fangguan') || u.contains('manager');
      if (isMgr) { if (mgrShown) continue; mgrShown = true; }
      shownBadges.add(u);
    }
    if (m.managerType > 0 && !mgrShown) shownBadges.add(DanmakuMessage.kBadgeManager);
    return GestureDetector(onTap: () => _showDanmakuActions(c, m),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (m.fansName.isNotEmpty)
                Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [fc.withOpacity(0.18), fc.withOpacity(0.08)]), border: Border.all(color: fc.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
                    child: Text('${m.fansLevel} ${m.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
              if (guard != null && guard.guardIcon.isNotEmpty)
                Padding(padding: const EdgeInsets.only(right: 4), child: Image.network(guard.guardIcon, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
              for (final url in shownBadges)
                Padding(padding: const EdgeInsets.only(right: 4), child: Image.network(url, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
              Text.rich(TextSpan(children: [
                const TextSpan(text: '', style: TextStyle(color: Color(0xFF4A5058), fontSize: 14, fontWeight: FontWeight.w600)),
                TextSpan(text: '${m.nickname.isEmpty ? "神秘用户" : m.nickname}: ', style: TextStyle(color: const Color(0xFF4A5058), fontSize: 14, fontWeight: FontWeight.w600)),
                ...buildEmoteSpans(m.content, textColor: const Color(0xFF23272E)),
              ])),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Obx(() {
      final list = c.danmakuList.where((m) => !m.isGift || c.showGiftList.value).toList();
      if (list.isEmpty) return Center(child: Text(c.danmakuStatus.value, style: const TextStyle(color: Color(0xFFA6ADB5))));
      return Stack(children: [
        Scrollbar(controller: _sc, thumbVisibility: true, thickness: 4, radius: const Radius.circular(4),
            child: ListView.builder(controller: _sc, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: list.length, itemBuilder: (_, i) => _item(c, list[i]))),
        Positioned(right: 8, bottom: 12, child: GlassContainer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 999),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          useOwnLayer: true,
          quality: GlassQuality.premium,
          settings: _lightGlassLocal(),
          child: Column(children: [
            GlassIconButton(icon: const Icon(Icons.tune, color: Color(0xFF3C4248)), size: 38, onPressed: () => _showDanmakuSettingsLocal(c)),
            const SizedBox(height: 4),
            GlassIconButton(icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF3C4248)), size: 38,
                onPressed: () => _sc.hasClients ? _sc.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null),
            const SizedBox(height: 4),
            GlassIconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3C4248)), size: 38,
                onPressed: () => _sc.hasClients ? _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null),
          ]),
        )),
      ]);
    });
  }

  LiquidGlassSettings _lightGlassLocal() => LiquidGlassSettings(
        glassColor: const Color(0xB3FFFFFF), thickness: 24, blur: 12,
        lightIntensity: 0.6, specularSharpness: GlassSpecularSharpness.medium, saturation: 1.3,
      );

  void _showDanmakuSettingsLocal(LivePlayController c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('弹幕设置', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700))),
            ),
            Obx(() => ListTile(
                  title: const Text('飘屏显示礼物弹幕', style: TextStyle(color: kText, fontSize: 14)),
                  trailing: Switch(value: c.showGiftOverlay.value, activeColor: kAccent, onChanged: (v) => c.showGiftOverlay.value = v),
                )),
            Obx(() => ListTile(
                  title: const Text('列表显示礼物弹幕', style: TextStyle(color: kText, fontSize: 14)),
                  trailing: Switch(value: c.showGiftList.value, activeColor: kAccent, onChanged: (v) => c.showGiftList.value = v),
                )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 高能榜（浅色 Sheet 内容）
// ─────────────────────────────────────────────────────────────────────────────
class _HighEnergyBody extends StatefulWidget {
  final LivePlayController c;
  const _HighEnergyBody({required this.c});
  @override
  State<_HighEnergyBody> createState() => _HighEnergyBodyState();
}

class _HighEnergyBodyState extends State<_HighEnergyBody> with SingleTickerProviderStateMixin {
  late TabController _tab; List<VipUser> _guard = []; List<VipUser> _vip = []; StreamSubscription? _sub;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _sync(); _sub = widget.c.client.vipStream.listen((_) { if (mounted) setState(_sync); }); }
  void _sync() { _guard = List.from(widget.c.client.guardList); _vip = List.from(widget.c.client.vipList); }
  @override
  void dispose() { _sub?.cancel(); _tab.dispose(); super.dispose(); }

  Color _rankColor(int rank) { switch (rank) { case 1: return const Color(0xFFE0A400); case 2: return const Color(0xFF8A9099); case 3: return const Color(0xFFB0703A); default: return const Color(0xFFA6ADB5); } }
  Color _fansColor(int lv) { if (lv <= 6) return const Color(0xFF2E9BF5); if (lv <= 12) return const Color(0xFF00B8D4); if (lv <= 19) return const Color(0xFFE09300); if (lv <= 25) return const Color(0xFFE05586); if (lv <= 31) return const Color(0xFF9A4FE0); if (lv <= 40) return const Color(0xFFFF8800); return const Color(0xFFE5484D); }
  String _guardIconUrl(int lv) => 'https://diy-assets.msstatic.com/hyys/guardgrade202211/guardrank/$lv.png';
  bool _isGuardTitle(String s) => s == '剑士' || s == '骑士' || s == '领主';
  Widget _img(String url) => Padding(padding: const EdgeInsets.only(right: 4), child: Image.network(url, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox.shrink()));

  Widget _row(VipUser u, int index) {
    final fc = _fansColor(u.fansLevel);
    final gIcon = u.guardIcon.isNotEmpty ? u.guardIcon : (u.guardLevel > 0 ? _guardIconUrl(u.guardLevel) : '');
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
      SizedBox(width: 30, child: Text('${index + 1}', textAlign: TextAlign.center, style: TextStyle(color: _rankColor(index + 1), fontSize: 15, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      CircleAvatar(radius: 22, backgroundColor: const Color(0xFFF2F3F5), backgroundImage: u.avatar.isNotEmpty ? NetworkImage(u.avatar) : null, child: u.avatar.isEmpty ? const Icon(Icons.person, size: 22, color: Color(0xFFA6ADB5)) : null),
      const SizedBox(width: 10),
      if (u.fansName.isNotEmpty && !_isGuardTitle(u.fansName))
        Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [fc.withOpacity(0.18), fc.withOpacity(0.08)]), border: Border.all(color: fc.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
            child: Text('${u.fansLevel} ${u.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
      if (gIcon.isNotEmpty) _img(gIcon),
      if (u.nobleIcon.isNotEmpty) _img(u.nobleIcon),
      if (u.managerType > 0) _img(DanmakuMessage.kBadgeManager),
      Expanded(child: Text(u.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 14))),
    ]));
  }

  Widget _list(List<VipUser> users, String emptyText) {
    if (users.isEmpty) return Center(child: Text(emptyText, style: const TextStyle(color: Color(0xFFA6ADB5), fontSize: 13)));
    return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(vertical: 8), itemCount: users.length, itemBuilder: (_, i) => _row(users[i], i));
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TabBar(controller: _tab, labelColor: kAccent, unselectedLabelColor: const Color(0xFF5F6672), indicatorColor: kAccent, tabs: [Tab(text: '守护 (${_guard.length})'), Tab(text: '贵宾 (${_vip.length})')]),
      ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: TabBarView(controller: _tab, children: [_list(_guard, '暂无守护'), _list(_vip, '暂无贵宾')])),
    ]);
  }
}

class _DetailTab extends StatelessWidget {
  final LivePlayController c;
  const _DetailTab({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(padding: const EdgeInsets.all(12), children: [
      Container(padding: const EdgeInsets.all(12), decoration: _card(), child: Row(children: [
        CircleAvatar(radius: 26, backgroundColor: const Color(0xFFF2F3F5), backgroundImage: c.streamerAvatar.value.isNotEmpty ? NetworkImage(c.streamerAvatar.value) : null, child: c.streamerAvatar.value.isEmpty ? const Icon(Icons.person, color: Color(0xFFA6ADB5)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.streamerName.value.isEmpty ? '—' : c.streamerName.value, style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('房间号 ${c.roomId} · ${c.isLive.value ? "直播中" : "未开播"}', style: const TextStyle(color: kSub, fontSize: 12)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: c.isLive.value ? const Color(0x1AE5484D) : const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(10)),
            child: Text(c.isLive.value ? 'LIVE' : 'OFF', style: TextStyle(color: c.isLive.value ? const Color(0xFFE5484D) : kSub, fontSize: 12, fontWeight: FontWeight.w700))),
      ])),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: _card(), child: Row(children: [
        _stat(_fmt(c.fansCount.value), '粉丝'), _divider(), _stat(_fmt(c.heatCount.value), '热度'), _divider(), _stat('${c.qualities.length} 档', '清晰度'),
      ])),
      if (c.isLive.value && c.liveDurationText.value.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(), child: Row(children: [
          const Icon(Icons.schedule, color: Color(0xFF3E9E4C)), const SizedBox(width: 10),
          const Text('开播时长', style: TextStyle(color: Color(0xFF576066), fontSize: 14)), const Spacer(),
          Text(c.liveDurationText.value, style: const TextStyle(color: Color(0xFF3E9E4C), fontSize: 15, fontWeight: FontWeight.w700)),
        ])),
      ],
      if (!c.isLive.value && c.lastLiveText.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(), child: Row(children: [
          const Icon(Icons.history, color: Color(0xFF8A9099)), const SizedBox(width: 10),
          const Text('上次开播', style: TextStyle(color: Color(0xFF576066), fontSize: 14)), const Spacer(),
          Text(c.lastLiveText, style: const TextStyle(color: kSub, fontSize: 13)),
        ])),
      ],
      if (c.roomTitle.value.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('本场直播标题', style: TextStyle(color: Color(0xFF576066), fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(c.roomTitle.value, style: const TextStyle(color: kSub, fontSize: 13)),
        ])),
      ],
      if (c.liveSchedule.value.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: _card(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.schedule, color: kAccent, size: 16), SizedBox(width: 6), Text('日常开播预告', style: TextStyle(color: kAccent, fontSize: 14, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 6),
          Text(c.liveSchedule.value, style: const TextStyle(color: Color(0xFF576066), fontSize: 13, height: 1.4)),
        ])),
      ],
    ]));
  }

  String _fmt(int v) { if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿'; if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万'; return '$v'; }
  Widget _stat(String v, String label) => Expanded(child: Column(children: [Text(v, style: const TextStyle(color: kAccent, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: kSub, fontSize: 12))]));
  Widget _divider() => Container(width: 1, height: 30, color: kLine);
  BoxDecoration _card() => BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine));
}

class _DebugTab extends StatelessWidget {
  final LivePlayController c;
  const _DebugTab({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!AppSettings.to.debugEnabled.value) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bug_report_outlined, color: Color(0xFFC4C9CF), size: 40),
          const SizedBox(height: 8),
          const Text('调试模式已关闭', style: TextStyle(color: kSub)),
          const SizedBox(height: 12),
          GlassButton(icon: const Icon(Icons.power_settings_new), label: '开启调试', onTap: () => AppSettings.to.setDebug(true)),
        ]));
      }
      return ListView(padding: const EdgeInsets.all(12), children: [
        const Text('协议调试日志', style: TextStyle(color: Color(0xFF00B8D4), fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SelectableText(c.debugInfo.value.isEmpty ? '（暂无日志）' : c.debugInfo.value, style: const TextStyle(color: Color(0xFF576066), fontSize: 12, height: 1.7)),
        const SizedBox(height: 12),
        Text('状态：${c.danmakuStatus.value}', style: const TextStyle(color: kSub, fontSize: 12)),
      ]);
    });
  }
}
