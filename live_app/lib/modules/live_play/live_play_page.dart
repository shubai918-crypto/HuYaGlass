import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  bool _videoReady = false;
  Worker? _nameWorker;
  Worker? _avatarWorker;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _videoReady = true);
    });
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
      body: Stack(children: [
        Column(children: [
          SizedBox(height: top),
          GlassMaterialize(visible: _chromeVisible, child: _header()),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(children: [
              c.videoHost(false),
              AnimatedOpacity(
                opacity: _videoReady ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                child: IgnorePointer(
                  ignoring: _videoReady,
                  child: Container(
                    color: kBg,
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 28, height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent)),
                        const SizedBox(height: 10),
                        const Text('连接直播中...', style: TextStyle(color: kSub, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          _tabs(),
          Expanded(child: TabBarView(controller: _tab, children: [
            _DanmakuList(c: c), _DetailTab(c: c), _DebugTab(c: c),
          ])),
        ]),
        Positioned(
          left: 14, right: 14, bottom: 12,
          child: GlassMaterialize(visible: _chromeVisible, child: _bottomBar()),
        ),
      ]),
    );
  }

  Widget _header() {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: GlassContainer(
            shape: const LiquidRoundedSuperellipse(borderRadius: 24),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            useOwnLayer: true, quality: GlassQuality.standard,
            settings: LiquidGlassSettings(
              blur: 10, thickness: 24, refractiveIndex: 1.1, saturation: 1.1,
              glassColor: const Color(0xCC101014),
              platformViewMode: PlatformViewGlassMode.passthrough,
              bodyMode: GlassBodyMode.clear,
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
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    settings: LiquidGlassSettings(blur: 8, thickness: 16, glassColor: const Color(0x66FFB25E), lightIntensity: 0.6),
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
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    settings: LiquidGlassSettings(blur: 8, thickness: 16,
                        glassColor: c.isFollowed.value ? Colors.white.withOpacity(0.15) : const Color(0x88E5484D), lightIntensity: 0.6),
                    child: Text(c.isFollowed.value ? '已订阅' : '订阅', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const Spacer(),
                GlassMenu(
                  settings: _menuLightGlass(),
                  quality: GlassQuality.premium,
                  menuWidth: 210,
                  triggerBuilder: (context, toggle) => GlassButton.custom(
                    onTap: toggle,
                    width: 40, height: 40,
                    shape: const LiquidOval(),
                    quality: GlassQuality.standard,
                    useOwnLayer: true,
                    settings: LiquidGlassSettings(glassColor: Colors.white.withOpacity(0.14), thickness: 18, blur: 8, lightIntensity: 0.4),
                    child: const Center(child: Icon(Icons.more_horiz, color: Colors.white, size: 20)),
                  ),
                  items: [
                    GlassMenuItem(title: '复制房间链接', icon: const Icon(Icons.link), onTap: _copyUrl),
                    GlassMenuItem(title: '刷新线路', icon: const Icon(Icons.refresh), onTap: c.refreshPlay),
                    GlassMenuItem(title: c.isMuted.value ? '取消静音' : '静音',
                        icon: Icon(c.isMuted.value ? Icons.volume_up : Icons.volume_off), onTap: c.toggleMute),
                    GlassMenuItem(title: c.isFullscreen.value ? '退出全屏' : '全屏',
                        icon: Icon(c.isFullscreen.value ? Icons.fullscreen_exit : Icons.fullscreen), onTap: c.toggleFullscreen),
                  ],
                ),
              ]),
            ]),
          ),
        ));
  }

  LiquidGlassSettings _menuLightGlass() => LiquidGlassSettings(
        glassColor: const Color(0xE6F2F2F7),
        thickness: 26, blur: 18, lightIntensity: 0.3, saturation: 1.2,
        refractiveIndex: 1.15, specularSharpness: GlassSpecularSharpness.medium, shadowElevation: 2.0,
      );

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
        settings: _barGlass(),
        child: TabBar(
          controller: _tab,
          indicatorColor: kAccent,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelColor: kAccent,
          unselectedLabelColor: const Color(0xFF5F6672),
          tabs: const [Tab(text: '弹幕'), Tab(text: '主播详情'), Tab(text: '调试')],
        ),
      ),
    );
  }

Widget _bottomBar() {
    return Row(children: [
      // ★ 1. 宽度变小：去掉 Expanded，固定宽度 140
      SizedBox(
        width: 140,
        child: GlassButton.custom(
          onTap: () => _openComposeSheet(),
          height: 54,
          useOwnLayer: true,
          quality: GlassQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 27),
          settings: _hdrGlass(),
          stretch: 0.8,
          resistance: 0.05,
          interactionScale: 1.05,
          anchorStretchSettings: const AnchorStretchSettings(
              intensity: 0.8, squashFactor: 0.2, translationDamping: 0.08, bounciness: 0.35),
          // ★ 2. 居中 + 粗黑文字
          child: Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: c.inputController,
              builder: (context, v, _) => Text(
                v.text.isEmpty ? '发弹幕' : v.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2329), // ★ 纯黑
                  fontSize: 15,
                  fontWeight: FontWeight.w700, // ★ 粗体
                ),
              ),
            ),
          ),
        ),
      ),
      const Spacer(), // ★ 中间留白，让左右分开
      // 右侧图标组保持不变
      GlassButtonGroup.icons(
        useOwnLayer: true,
        quality: GlassQuality.premium,
        borderRadius: 27,
        iconSize: 24,
        showDividers: false,
        itemPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        settings: _hdrGlass(),
        items: [
          GlassButtonGroupItem(label: '清晰度', icon: const Icon(Icons.speed, color: Color(0xFF3C4248)), onTap: _openQualitySheet),
          GlassButtonGroupItem(label: '弹幕设置', icon: const Icon(Icons.tune, color: Color(0xFF3C4248)), onTap: _showDanmakuSettingsSheet),
          GlassButtonGroupItem(label: '表情', icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF3C4248)), onTap: () => _openComposeSheet(focusEmoji: true)),
        ],
      ),
    ]);
  }

// ★ 恢复 iOS 标准浅色磨砂：90% 白纱 + 强模糊，去掉 clear 模式
  LiquidGlassSettings _barGlass() => LiquidGlassSettings(
        glassColor: const Color(0xE6FFFFFF), // 90% 白，明显的磨砂白卡片
        thickness: 28,
        blur: 20, // 强模糊，透出背后的轮廓
        lightIntensity: 0.3,
        ambientStrength: 0.1,
        fresnelStrength: 0.5,
        refractiveIndex: 1.15,
        saturation: 1.2,
        chromaticAberration: 0.01,
        specularSharpness: GlassSpecularSharpness.medium,
        shadowElevation: 2.0,
        // ★ 移除 bodyMode: GlassBodyMode.clear，恢复默认的自适应亮度
      );

  LiquidGlassSettings _hdrGlass() => _barGlass();

  void _openQualitySheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _LightSheet(child: _qualityContent()),
    );
  }

  void _openComposeSheet({bool focusEmoji = false}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
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
      backgroundColor: kCard,
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

class _LightSheet extends StatelessWidget {
  final Widget child;
  const _LightSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: kCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: const Color(0xFFD8DBE0), borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: child),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }
}

class _DanmakuComposeBody extends StatefulWidget {
  final LivePlayController c;
  final bool showEmojiInitial;
  const _DanmakuComposeBody({required this.c, this.showEmojiInitial = false});
  @override
  State<_DanmakuComposeBody> createState() => _DanmakuComposeBodyState();
}

class _DanmakuComposeBodyState extends State<_DanmakuComposeBody> {
  final FocusNode _fn = FocusNode();
  bool _focused = false;
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
    setState(() {
      _focused = _fn.hasFocus;
      if (_fn.hasFocus) { _emojiOpen = false; _phraseOpen = false; }
    });
  }

  @override
  void dispose() { _fn.removeListener(_onFocus); _fn.dispose(); super.dispose(); }

  void _toggleEmoji() { setState(() { _emojiOpen = !_emojiOpen; if (_emojiOpen) { _phraseOpen = false; _fn.unfocus(); } }); }
  void _togglePhrase() { setState(() { _phraseOpen = !_phraseOpen; if (_phraseOpen) { _emojiOpen = false; _fn.unfocus(); } }); }

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
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(16)),
        child: _focused
            ? TextField(
                controller: widget.c.inputController,
                focusNode: _fn,
                maxLines: 3, minLines: 1,
                style: const TextStyle(color: Color(0xFF23272E), fontSize: 15),
                cursorColor: kAccent,
                keyboardAppearance: Brightness.light,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendFlow(),
                decoration: const InputDecoration(
                  hintText: '发送弹幕...',
                  hintStyle: TextStyle(color: Color(0xFFA6ADB5), fontSize: 15),
                  border: InputBorder.none,
                ),
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).requestFocus(_fn),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.c.inputController,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const Align(alignment: Alignment.centerLeft,
                          child: Text('发送弹幕...', style: TextStyle(color: Color(0xFFA6ADB5), fontSize: 15)))
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(children: buildEmoteSpans(v.text, fontSize: 15, textColor: const Color(0xFF23272E))),
                            style: const TextStyle(color: Color(0xFF23272E), fontSize: 15, height: 1.5),
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
                decoration: BoxDecoration(color: can ? kAccent : const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(999)),
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
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)),
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

// ─────────────────────────────────────────────────────────────────────────────
// ★ 弹幕列表：智能滚动逻辑（自动追底 / 手动上滑暂停 / 点击下拉恢复）
// ─────────────────────────────────────────────────────────────────────────────
class _DanmakuList extends StatefulWidget {
  final LivePlayController c;
  const _DanmakuList({required this.c});
  @override
  State<_DanmakuList> createState() => _DanmakuListState();
}

class _DanmakuListState extends State<_DanmakuList> {
  final ScrollController _sc = ScrollController();
  bool _autoScroll = true;
  Worker? _listWorker;

  @override
  void initState() {
    super.initState();
    _sc.addListener(_onScroll);
    // ★ 监听列表变化，自动追底
    _listWorker = ever(widget.c.danmakuList, (_) {
      if (_autoScroll && _sc.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_autoScroll && _sc.hasClients && _sc.position.maxScrollExtent > 0) {
            _sc.animateTo(_sc.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
        });
      }
    });
  }

  void _onScroll() {
    if (!_sc.hasClients) return;
    final pos = _sc.position;
    // ★ 如果用户手动上滑超过 50px，暂停自动追底
    if (pos.pixels < pos.maxScrollExtent - 50) {
      if (_autoScroll) setState(() => _autoScroll = false);
    }
  }

  void _scrollToBottom() {
    setState(() => _autoScroll = true); // ★ 恢复自动追底
    if (_sc.hasClients) {
      _sc.animateTo(_sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _scrollToTop() {
    setState(() => _autoScroll = false); // ★ 上滑肯定暂停
    if (_sc.hasClients) {
      _sc.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
    _listWorker?.dispose();
    super.dispose();
  }

  Color _fansColor(int lv) {
    if (lv <= 6) return const Color(0xFF2E9BF5);
    if (lv <= 12) return const Color(0xFF00B8D4);
    if (lv <= 19) return const Color(0xFFE09300);
    if (lv <= 25) return const Color(0xFFE05586);
    if (lv <= 31) return const Color(0xFF9A4FE0);
    if (lv <= 40) return const Color(0xFFFF8800);
    return const Color(0xFFE5484D);
  }

  Color _contentColor(int rgb) {
    final c = Color(rgb);
    final l = (0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue) / 255;
    return l > 0.62 ? const Color(0xFF3C4248) : c;
  }

  LiquidGlassSettings _menuGlass() => LiquidGlassSettings(
        glassColor: const Color(0xCC1C1C1E),
        thickness: 22, blur: 12, lightIntensity: 0.25, saturation: 1.1,
        refractiveIndex: 1.1, specularSharpness: GlassSpecularSharpness.medium,
      );

  void _showDanmakuMenu(DanmakuMessage m, Offset pos) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => _DanmakuMenu(c: widget.c, m: m, pos: pos, menuGlass: _menuGlass(), onUserInfo: () {
        Navigator.of(context).pop();
        _showUserInfo(m);
      }),
    );
  }

  void _showUserInfo(DanmakuMessage m) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Center(
        child: Material(type: MaterialType.transparency, child: _UserInfoCard(m: m, c: widget.c, menuGlass: _menuGlass())),
      ),
    );
  }

  Widget _item(LivePlayController c, DanmakuMessage m) {
    final fc = _fansColor(m.fansLevel);
    if (m.isGift) {
      final icon = DanmakuMessage.kGiftIcons[m.giftName];
      return GestureDetector(
        onLongPressStart: (d) => _showDanmakuMenu(m, d.globalPosition),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (m.fansName.isNotEmpty)
                Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [fc.withOpacity(0.18), fc.withOpacity(0.08)]), border: Border.all(color: fc.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
                    child: Text('${m.fansLevel} ${m.fansName}', style: TextStyle(color: fc, fontSize: 10, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => _showUserInfo(m),
                child: Text('${m.nickname}: ', style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Text('送 ', style: TextStyle(color: Color(0xFF576066), fontSize: 14)),
              if (icon != null)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Image.network(icon, width: 20, height: 20, errorBuilder: (_, __, ___) => Text(m.giftName, style: const TextStyle(color: Color(0xFF576066), fontSize: 14))))
              else
                Text(m.giftName, style: const TextStyle(color: Color(0xFF576066), fontSize: 14)),
              Text(' ${m.giftCount}', style: const TextStyle(color: Color(0xFF576066), fontSize: 14)),
              if (m.comboCount > 1) Text(' ${m.comboCount}连击', style: const TextStyle(color: Color(0xFF8A9099), fontSize: 12)),
            ])),
      );
    }
    final guard = c.client.guardList.isNotEmpty ? c.client.guardList.firstWhereOrNull((g) => g.nickname == m.nickname) : null;
    final shownBadges = <String>[]; bool mgrShown = false;
    for (final u in m.badgeUrls) {
      final isMgr = u.contains('fangguan') || u.contains('manager');
      if (isMgr) { if (mgrShown) continue; mgrShown = true; }
      shownBadges.add(u);
    }
    if (m.managerType > 0 && !mgrShown) shownBadges.add(DanmakuMessage.kBadgeManager);
    return GestureDetector(
      onLongPressStart: (d) => _showDanmakuMenu(m, d.globalPosition),
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
            GestureDetector(
              onTap: () => _showUserInfo(m),
              child: Text('${m.nickname.isEmpty ? "神秘用户" : m.nickname}: ',
                  style: const TextStyle(color: Color(0xFF4A5058), fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text.rich(TextSpan(children: buildEmoteSpans(m.content, textColor: _contentColor(m.fontColor)))),
          ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Obx(() {
      final list = c.danmakuList.where((m) => !m.isGift || c.showGiftList.value).toList();
      if (list.isEmpty) return Center(child: Text(c.danmakuStatus.value, style: const TextStyle(color: Color(0xFFA6ADB5))));
      return Stack(children: [
        Scrollbar(controller: _sc, thumbVisibility: true, thickness: 4, radius: const Radius.circular(4),
            child: ListView.builder(controller: _sc, padding: const EdgeInsets.fromLTRB(12, 8, 12, 84), itemCount: list.length, itemBuilder: (_, i) => _item(c, list[i]))),
        Positioned(right: 8, bottom: 84, child: GlassContainer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 999),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          settings: LiquidGlassSettings(glassColor: const Color(0xB3FFFFFF), thickness: 20, blur: 8, lightIntensity: 0.5, specularSharpness: GlassSpecularSharpness.medium, saturation: 1.1),
          child: Column(children: [
            GlassIconButton(icon: const Icon(Icons.tune, color: Color(0xFF3C4248)), size: 38, onPressed: () => _showDanmakuSettingsLocal(c)),
            const SizedBox(height: 4),
            GlassIconButton(icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF3C4248)), size: 38,
                onPressed: _scrollToTop), // ★ 快速上拉
            const SizedBox(height: 4),
            GlassIconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3C4248)), size: 38,
                onPressed: _scrollToBottom), // ★ 快速下拉
          ]),
        )),
      ]);
    });
  }

  void _showDanmakuSettingsLocal(LivePlayController c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
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

class _UserInfoCard extends StatefulWidget {
  final DanmakuMessage m;
  final LivePlayController c;
  final LiquidGlassSettings menuGlass;
  const _UserInfoCard({required this.m, required this.c, required this.menuGlass});
  @override
  State<_UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends State<_UserInfoCard> {
  String _avatar = '';

  @override
  void initState() {
    super.initState();
    _resolveAvatar();
  }

  Future<void> _resolveAvatar() async {
    final nick = widget.m.nickname;
    final uid = widget.m.uid;
    try {
      final pool = [...widget.c.client.guardList, ...widget.c.client.vipList];
      for (final u in pool) {
        final dyn = u as dynamic;
        final uUid = (dyn.uid is int) ? dyn.uid as int : 0;
        if ((nick.isNotEmpty && u.nickname == nick) || (uid > 0 && uUid == uid)) {
          if (u.avatar.isNotEmpty && mounted) { setState(() => _avatar = u.avatar); return; }
        }
      }
    } catch (_) {}
    if (uid > 0) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final req = await client.getUrl(Uri.parse('https://www.huya.com/$uid')).timeout(const Duration(seconds: 5));
        req.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
        req.headers.set('Referer', 'https://www.huya.com/');
        final resp = await req.close().timeout(const Duration(seconds: 5));
        final body = await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
        client.close(force: true);
        final m2 = RegExp(r'"avatar"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(body);
        if (m2 != null) {
          final url = m2.group(1)!.replaceAll(r'\/', '/');
          if (url.isNotEmpty && mounted) setState(() => _avatar = url);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final fc = _fansColorLocal(m.fansLevel);
    return GlassContainer(
      shape: const LiquidRoundedSuperellipse(borderRadius: 28),
      padding: const EdgeInsets.all(24),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      settings: widget.menuGlass,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: const Color(0xFF2A2A34),
          backgroundImage: _avatar.isNotEmpty ? NetworkImage(_avatar) : null,
          child: _avatar.isEmpty
              ? Text(m.nickname.isNotEmpty ? m.nickname[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white70, fontSize: 28, fontWeight: FontWeight.w800))
              : null,
        ),
        const SizedBox(height: 12),
        Text(m.nickname.isEmpty ? '神秘用户' : m.nickname,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          _chipLocal('UID: ${m.uid > 0 ? m.uid : '未知'}', const Color(0xFF8A9099)),
          if (m.fansName.isNotEmpty) _chipLocal('${m.fansLevel} ${m.fansName}', fc),
          if (m.managerType > 0) _chipLocal('房管', const Color(0xFFE5484D)),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GlassButton.custom(
            onTap: () {
              widget.c.inputController.text = '@${m.nickname} ';
              Navigator.of(context).pop();
              Get.snackbar('打招呼', '已填入 @${m.nickname}', snackPosition: SnackPosition.BOTTOM);
            },
            height: 40,
            shape: const LiquidRoundedRectangle(borderRadius: 20),
            quality: GlassQuality.standard,
            settings: LiquidGlassSettings(glassColor: const Color(0x66FF8800), thickness: 18, blur: 2, bodyMode: GlassBodyMode.clear),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('打招呼', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          GlassButton.custom(
            onTap: () => Navigator.of(context).pop(),
            height: 40,
            shape: const LiquidRoundedRectangle(borderRadius: 20),
            quality: GlassQuality.standard,
            settings: LiquidGlassSettings(glassColor: const Color(0x33FFFFFF), thickness: 18, blur: 2),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('关闭', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }

  Color _fansColorLocal(int lv) {
    if (lv <= 6) return const Color(0xFF2E9BF5);
    if (lv <= 12) return const Color(0xFF00B8D4);
    if (lv <= 19) return const Color(0xFFE09300);
    if (lv <= 25) return const Color(0xFFE05586);
    if (lv <= 31) return const Color(0xFF9A4FE0);
    if (lv <= 40) return const Color(0xFFFF8800);
    return const Color(0xFFE5484D);
  }

  Widget _chipLocal(String label, Color tint) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tint.withOpacity(0.18),
          border: Border.all(color: tint.withOpacity(0.55)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _DanmakuMenu extends StatefulWidget {
  final LivePlayController c;
  final DanmakuMessage m;
  final Offset pos;
  final LiquidGlassSettings menuGlass;
  final VoidCallback onUserInfo;
  const _DanmakuMenu({required this.c, required this.m, required this.pos, required this.menuGlass, required this.onUserInfo});
  @override
  State<_DanmakuMenu> createState() => _DanmakuMenuState();
}

class _DanmakuMenuState extends State<_DanmakuMenu> {
  bool _expanded = false;

  void _done() => Navigator.of(context).pop();

  String get _content => widget.m.isGift ? '${widget.m.nickname} 送 ${widget.m.giftName}' : widget.m.content;

  void _copy() {
    Clipboard.setData(ClipboardData(text: _content));
    Get.snackbar('提示', '已复制到剪贴板', snackPosition: SnackPosition.BOTTOM);
    _done();
  }

  void _repeat() {
    if (!widget.m.isGift) widget.c.sendDanmaku(widget.m.content);
    _done();
  }

  void _quote() {
    widget.c.inputController.text = widget.m.content;
    Get.snackbar('引用', '内容已填入输入框', snackPosition: SnackPosition.BOTTOM);
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = _expanded ? 232.0 : 196.0;
    final h = _expanded ? 268.0 : 52.0;
    final left = widget.pos.dx.clamp(8.0, size.width - w - 8);
    final top = (widget.pos.dy - 60).clamp(80.0, size.height - h - 140);
    return Stack(children: [
      Positioned(
        left: left, top: top,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _expanded ? _verticalMenu() : _capsule(),
        ),
      ),
    ]);
  }

  Widget _capsule() {
    return GlassButtonGroup.icons(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      borderRadius: 26,
      iconSize: 18,
      itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      settings: widget.menuGlass,
      items: [
        GlassButtonGroupItem(label: '复制', icon: const Icon(Icons.copy, color: Colors.white70), onTap: _copy),
        GlassButtonGroupItem(label: '+1', icon: const Icon(Icons.send, color: Color(0xFFFF8800)), onTap: _repeat),
        GlassButtonGroupItem(label: '引用', icon: const Icon(Icons.format_quote, color: Colors.white70), onTap: _quote),
        GlassButtonGroupItem(label: '更多', icon: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () => setState(() => _expanded = true)),
      ],
    );
  }

  Widget _verticalMenu() {
    return GlassContainer(
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      settings: widget.menuGlass,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _row(Icons.copy, Colors.white70, '复制内容', _copy),
        _divider(),
        _row(Icons.send, const Color(0xFFFF8800), '+1 复读', _repeat),
        _divider(),
        _row(Icons.format_quote, Colors.white70, '引用到输入框', _quote),
        _divider(),
        _row(Icons.person, const Color(0xFF00B8D4), '查看用户信息', widget.onUserInfo),
        _divider(),
        _row(Icons.block, const Color(0xFFE5484D), '屏蔽该弹幕', () {
          Get.snackbar('屏蔽', '已本地屏蔽 ${widget.m.nickname}', snackPosition: SnackPosition.BOTTOM);
          _done();
        }),
      ]),
    );
  }

  Widget _divider() => Container(height: 0.5, color: Colors.white.withOpacity(0.08), margin: const EdgeInsets.only(left: 44));

  Widget _row(IconData icon, Color color, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

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
    return ListView.builder(padding: const EdgeInsets.symmetric(vertical: 8), itemCount: users.length, itemBuilder: (_, i) => _row(users[i], i));
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TabBar(controller: _tab, labelColor: kAccent, unselectedLabelColor: const Color(0xFF5F6672), indicatorColor: kAccent, dividerColor: Colors.transparent, tabs: [Tab(text: '守护 (${_guard.length})'), Tab(text: '贵宾 (${_vip.length})')]),
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.45,
        child: TabBarView(controller: _tab, children: [_list(_guard, '暂无守护'), _list(_vip, '暂无贵宾')]),
      ),
    ]);
  }
}

class _DetailTab extends StatelessWidget {
  final LivePlayController c;
  const _DetailTab({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 84), children: [
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
      return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 84), children: [
        const Text('协议调试日志', style: TextStyle(color: Color(0xFF00B8D4), fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SelectableText(c.debugInfo.value.isEmpty ? '（暂无日志）' : c.debugInfo.value, style: const TextStyle(color: Color(0xFF576066), fontSize: 12, height: 1.7)),
        const SizedBox(height: 12),
        Text('状态：${c.danmakuStatus.value}', style: const TextStyle(color: kSub, fontSize: 12)),
      ]);
    });
  }
}
