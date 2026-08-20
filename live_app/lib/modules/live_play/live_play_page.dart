import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/danmaku_view.dart';
import 'huya_web_sender.dart';
import 'live_play_controller.dart';

class LivePlayPage extends StatelessWidget {
  const LivePlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LivePlayController());
    return Obx(() => PopScope(
          canPop: !controller.isFullscreen.value,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.toggleFullscreen();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0A0F),
            body: Stack(
              children: [
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
                        Expanded(child: _DanmakuList(controller: controller)),
                        _buildBottomBar(controller),
                      ],
                    );
                  }),
                ),
                Obx(() => controller.isFullscreen.value
                    ? Container(
                        color: Colors.black,
                        child: Stack(children: [
                          Positioned.fill(child: controller.fullscreenWidget()),
                          if (controller.showDanmaku.value &&
                              controller.danmakuStream != null)
                            Positioned(
                              top: 50,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: DanmakuView(
                                  danmakuStream: controller.danmakuStream!,
                                  height: 160,
                                  fontSize: controller.danmakuFontSize.value,
                                ),
                              ),
                            ),
                        ]),
                      )
                    : const SizedBox.shrink()),
                // 关键：登录后挂载隐藏 WebView 发送器（1x1 不可见）
                if (HuyaLoginManager().isLoggedIn)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 1,
                    height: 1,
                    child: HuyaWebSender(
                      roomId: controller.roomId,
                      onFans: (v) => controller.fansCount.value = v,
                    ),
                  ),
              ],
            ),
          ),
        ));
  }

  Widget _defaultAvatar() => Container(
        width: 44,
        height: 44,
        color: const Color(0xFF2D2D44),
        child: const Icon(Icons.person, color: Colors.white54),
      );

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
                  '粉丝 ${_formatCount(controller.fansCount.value)} · 热度 ${_formatCount(controller.heatCount.value)}',
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

  Widget _buildVideoArea(LivePlayController controller) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(child: controller.videoWidget()),
          if (controller.showDanmaku.value && controller.danmakuStream != null)
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: DanmakuView(
                  danmakuStream: controller.danmakuStream!,
                  height: 140,
                  fontSize: controller.danmakuFontSize.value,
                ),
              ),
            ),
        ],
      ),
    );
  }

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
