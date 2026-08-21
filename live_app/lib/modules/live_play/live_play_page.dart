import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/danmaku_view.dart';
import 'live_play_controller.dart';

class LivePlayPage extends StatelessWidget {
  const LivePlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LivePlayController());
    return Obx(() {
      final fs = controller.isFullscreen.value;
      return PopScope(
        canPop: !fs,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.toggleFullscreen();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          // 竖屏永远挂载；全屏=覆盖层复用同一 textureId → 视频不重建，黑屏根治
          body: Stack(children: [
            SafeArea(
              child: Obx(() {
                if (controller.loading.value) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00D2FF)));
                }
                return Column(
                  children: [
                    _buildTopBar(controller),
                    _buildVideoArea(controller),
                    Expanded(child: _InfoTabs(controller: controller)),
                    _buildBottomBar(controller),
                  ],
                );
              }),
            ),
            Obx(() => controller.isFullscreen.value
                ? _buildFullscreenOverlay(controller)
                : const SizedBox.shrink()),
          ]),
        ),
      );
    });
  }

  // ================= 全屏覆盖层 =================
  Widget _buildFullscreenOverlay(LivePlayController controller) {
    return Material(
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(child: controller.fullscreenOverlay()),
        const _KeepAliveRepaint(),
        Obx(() => controller.showDanmaku.value && controller.danmakuStream != null
            ? Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: DanmakuView(
                    danmakuStream: controller.danmakuStream!,
                    height: 220 * controller.danmakuArea.value,
                    fontSize: controller.danmakuFontSize.value,
                    fps: controller.danmakuFps.value,
                    speed: controller.danmakuSpeed.value,
                    opacity: controller.danmakuOpacity.value,
                  ),
                ),
              )
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _defaultAvatar() => Container(
        width: 44,
        height: 44,
        color: const Color(0xFF2D2D44),
        child: const Icon(Icons.person, color: Colors.white54),
      );

  // ================= 顶栏 =================
  Widget _buildTopBar(LivePlayController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: controller.streamerAvatar.value.isNotEmpty
                ? Image.network(
                    controller.streamerAvatar.value,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.streamerName.value.isEmpty
                      ? '虎牙主播'
                      : controller.streamerName.value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '粉丝 ${_formatCount(controller.fansCount.value)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleFollow(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: controller.isFollowed.value
                    ? const Color(0xFFFF6B6B).withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: controller.isFollowed.value
                        ? const Color(0xFFFF6B6B)
                        : Colors.white.withOpacity(0.15)),
              ),
              child: Text(
                controller.isFollowed.value ? '已订阅' : '订阅',
                style: TextStyle(
                    color: controller.isFollowed.value
                        ? const Color(0xFFFF6B6B)
                        : Colors.white70,
                    fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 视频区（竖屏，唯一真实 VideoPlayer） =================
  Widget _buildVideoArea(LivePlayController controller) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (c, cons) => Stack(
          children: [
            Positioned.fill(child: controller.videoHost(false)),
            Obx(() => controller.showDanmaku.value && controller.danmakuStream != null
                ? Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: DanmakuView(
                        danmakuStream: controller.danmakuStream!,
                        height: cons.maxHeight * controller.danmakuArea.value,
                        fontSize: controller.danmakuFontSize.value,
                        fps: controller.danmakuFps.value,
                        speed: controller.danmakuSpeed.value,
                        opacity: controller.danmakuOpacity.value,
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  // ================= 底部 =================
  Widget _buildBottomBar(LivePlayController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.qualities.isNotEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: controller.qualities.map((q) {
                  final selected = q.name == controller.currentQuality.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => controller.switchQuality(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF00D2FF).withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: selected
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          q.name,
                          style: TextStyle(
                              color: selected ? const Color(0xFF00D2FF) : Colors.white60,
                              fontSize: 12),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Obx(() => ListView(
                    scrollDirection: Axis.horizontal,
                    children: List.generate(controller.lines.length, (i) {
                      final selected = i == controller.currentLine.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => controller.switchLine(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF00D2FF).withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selected
                                      ? const Color(0xFF00D2FF)
                                      : Colors.white.withOpacity(0.1)),
                            ),
                            child: Text(
                              '线路${i + 1}',
                              style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF00D2FF)
                                      : Colors.white60,
                                  fontSize: 11),
                            ),
                          ),
                        ),
                      );
                    }),
                  )),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '发送弹幕...',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                  ),
                  onSubmitted: (t) => controller.sendDanmaku(t),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => controller.sendDanmaku(controller.inputController.text),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return '$count';
  }
}

// ================= 全屏保活重绘 =================
class _KeepAliveRepaint extends StatefulWidget {
  const _KeepAliveRepaint();

  @override
  State<_KeepAliveRepaint> createState() => _KeepAliveRepaintState();
}

class _KeepAliveRepaintState extends State<_KeepAliveRepaint> {
  Timer? _t;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 2,
        height: 2,
        child: CustomPaint(painter: _TickPainter(_tick)),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final int tick;
  const _TickPainter(this.tick);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0x01000000),
    );
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.tick != tick;
}

// ================= 双 Tab / 详情 / 列表（同前） =================
class _InfoTabs extends StatefulWidget {
  final LivePlayController controller;
  const _InfoTabs({required this.controller});

  @override
  State<_InfoTabs> createState() => _InfoTabsState();
}

class _InfoTabsState extends State<_InfoTabs> {
  int _tab = 0;

  Widget _tabBtn(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF00D2FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF00D2FF) : Colors.white54,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _tabBtn('弹幕', 0),
            _tabBtn('主播详情', 1),
            const Spacer(),
          ],
        ),
        const Divider(height: 1, color: Color(0xFF2A2A35)),
        Expanded(
          child: _tab == 0
              ? _DanmakuList(controller: widget.controller)
              : _DetailTab(controller: widget.controller),
        ),
      ],
    );
  }
}

class _DetailTab extends StatelessWidget {
  final LivePlayController controller;
  const _DetailTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: controller.streamerAvatar.value.isNotEmpty
                        ? Image.network(
                            controller.streamerAvatar.value,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person, color: Colors.white54, size: 30),
                          )
                        : const Icon(Icons.person, color: Colors.white54, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.streamerName.value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '房间号 ${controller.roomId} · ${controller.isLive.value ? "直播中" : "未开播"}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.55), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: controller.isLive.value
                          ? const Color(0xFFFF6B6B).withOpacity(0.2)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      controller.isLive.value ? 'LIVE' : 'OFF',
                      style: TextStyle(
                          color: controller.isLive.value
                              ? const Color(0xFFFF6B6B)
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  _statCell('粉丝', _formatFull(controller.fansCount.value)),
                  _divider(),
                  _statCell('热度', _formatFull(controller.heatCount.value)),
                  _divider(),
                  _statCell('清晰度', '${controller.qualities.length} 档'),
                ],
              ),
            ),
            Obx(() => controller.liveDurationText.value.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Color(0xFF7ED97E), size: 20),
                          const SizedBox(width: 10),
                          const Text('开播时长',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const Spacer(),
                          Text(
                            controller.liveDurationText.value,
                            style: const TextStyle(
                                color: Color(0xFF7ED97E),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
            const SizedBox(height: 12),
            if (controller.roomTitle.value.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('直播标题',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      controller.roomTitle.value,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ));
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withOpacity(0.1),
      );

  Widget _statCell(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                  color: Color(0xFF00D2FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
      );

  String _formatFull(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return '$count';
  }
}

class _DanmakuList extends StatefulWidget {
  final LivePlayController controller;
  const _DanmakuList({required this.controller});

  @override
  State<_DanmakuList> createState() => _DanmakuListState();
}

class _DanmakuListState extends State<_DanmakuList> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = widget.controller.danmakuList;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
      if (list.isEmpty) {
        return Center(
          child: Obx(() => Text(
                widget.controller.danmakuStatus.value,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              )),
        );
      }
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: list.length,
        itemBuilder: (c, i) {
          final m = list[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${m.nickname}: ',
                    style: const TextStyle(
                        color: Color(0xFF00D2FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: m.content,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
