import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/danmaku_view.dart';
import '../../common/widgets/liquid_glass.dart';
import 'live_play_controller.dart';

class LivePlayPage extends StatelessWidget {
  const LivePlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LivePlayController());
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
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
    );
  }

  Widget _defaultAvatar() => Container(
        width: 44,
        height: 44,
        color: const Color(0xFF2D2D44),
        child: const Icon(Icons.person, color: Colors.white54),
      );

  Widget _buildTopBar(LivePlayController controller) {
    return LiquidGlass(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '粉丝 ${_formatCount(controller.fansCount.value)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          LiquidGlassButton(
            text: controller.isFollowed.value ? '已订阅' : '订阅',
            selected: controller.isFollowed.value,
            selectedColor: const Color(0xFFFF6B6B),
            onTap: () => controller.toggleFollow(),
          ),
          const SizedBox(width: 8),
          LiquidGlassIconButton(icon: Icons.close, size: 36, onTap: () => Get.back()),
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
    return LiquidGlass(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.qualities.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: controller.qualities.map((q) {
                  final selected = q.name == controller.currentQuality.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: LiquidGlassButton(
                      text: q.name,
                      selected: selected,
                      fontSize: 12,
                      onTap: () => controller.switchQuality(q),
                    ),
                  );
                }).toList(),
              ),
            ),
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
              LiquidGlassIconButton(
                icon: Icons.send_rounded,
                size: 42,
                color: const Color(0xFF00D2FF),
                onTap: () => controller.sendDanmaku(controller.inputController.text),
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

/// 视频下方的弹幕列表（自动滚动到底部）
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
