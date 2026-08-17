import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/liquid_glass.dart';
import '../../common/widgets/danmaku_view.dart';
import 'live_play_controller.dart';

class LivePlayPage extends StatelessWidget {
  const LivePlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LivePlayController());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
          );
        }
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Stack(
            children: [
              // 视频播放器
              Positioned.fill(child: controller.videoWidget()),

              // 弹幕层
              if (controller.showDanmaku.value && controller.danmakuStream != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  left: 0,
                  right: 0,
                  child: DanmakuView(
                    danmakuStream: controller.danmakuStream!,
                    height: 240,
                    fontSize: controller.danmakuFontSize.value,
                  ),
                ),

              // 顶部信息栏（液态玻璃）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildTopBar(context, controller)),
              ),

              // 底部控制栏（液态玻璃）
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildBottomBar(context, controller)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopBar(BuildContext context, LivePlayController controller) {
    return LiquidGlass(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // 主播头像
          ClipOval(
            child: controller.streamerAvatar.value.isNotEmpty
                ? Image.network(
                    controller.streamerAvatar.value,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF2D2D44),
                    child: const Icon(Icons.person, color: Colors.white54),
                  ),
          ),
          const SizedBox(width: 12),
          // 主播信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.streamerName.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '粉丝 ${_formatCount(controller.fansCount.value)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 订阅按钮
          LiquidGlassButton(
            text: controller.isFollowed.value ? '已订阅' : '订阅',
            selected: controller.isFollowed.value,
            selectedColor: const Color(0xFFFF6B6B),
            onTap: () => controller.toggleFollow(),
          ),
          const SizedBox(width: 8),
          // 关闭
          LiquidGlassIconButton(
            icon: Icons.close,
            size: 36,
            onTap: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, LivePlayController controller) {
    return LiquidGlass(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 画质切换
          if (controller.qualities.isNotEmpty)
            Row(
              children: [
                Text(
                  '画质',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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
                ),
              ],
            ),
          const SizedBox(height: 12),
          // 弹幕输入框
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '发送弹幕...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (text) => controller.sendDanmaku(text),
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
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return '$count';
  }
}
