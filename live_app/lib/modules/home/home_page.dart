import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/widgets/liquid_glass.dart';
import '../../app/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'HuyaLive',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  LiquidGlassIconButton(
                    icon: Icons.settings_outlined,
                    onTap: () => Get.toNamed(AppRoutes.settings),
                  ),
                ],
              ),
            ),

            // 功能入口
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 搜索入口
                    LiquidGlass(
                      padding: const EdgeInsets.all(20),
                      child: GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.search),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF00D2FF), size: 28),
                            const SizedBox(width: 16),
                            const Text(
                              '搜索直播间',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 订阅入口
                    LiquidGlass(
                      padding: const EdgeInsets.all(20),
                      child: GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.follow),
                        child: Row(
                          children: [
                            const Icon(Icons.subscriptions_outlined, color: Color(0xFFFF6B6B), size: 28),
                            const SizedBox(width: 16),
                            const Text(
                              '我的订阅',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 快速进入直播间
                    LiquidGlass(
                      padding: const EdgeInsets.all(20),
                      child: GestureDetector(
                        onTap: () => _showRoomIdDialog(context),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_outline, color: Color(0xFF6C5CE7), size: 28),
                            const SizedBox(width: 16),
                            const Text(
                              '进入直播间',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomIdDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('输入房间号', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '例如: 116, 660000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final roomId = controller.text.trim();
              if (roomId.isNotEmpty) {
                Navigator.pop(ctx);
                Get.toNamed('${AppRoutes.livePlay}?roomId=$roomId');
              }
            },
            child: const Text('进入', style: TextStyle(color: Color(0xFF00D2FF))),
          ),
        ],
      ),
    );
  }
}
