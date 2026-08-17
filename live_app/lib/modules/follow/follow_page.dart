import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/liquid_glass.dart';
import '../../app/routes.dart';
import 'follow_controller.dart';

class FollowPage extends StatelessWidget {
  const FollowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FollowController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的订阅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.followedList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.subscriptions_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  '暂无订阅主播',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                ),
              ],
            ),
          );
        }

        // 直播中的排前面（参考 dtv_mobile FollowScreen）
        final live = controller.followedList.where((r) => r.isLive).toList();
        final offline = controller.followedList.where((r) => !r.isLive).toList();
        final sorted = [...live, ...offline];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final room = sorted[index];
            return _FollowItem(room: room);
          },
        );
      }),
    );
  }
}

class _FollowItem extends StatelessWidget {
  final LiveRoom room;

  const _FollowItem({required this.room});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (room.isLive) {
          Get.toNamed(
            '${AppRoutes.livePlay}?roomId=${room.roomId}&uid=${room.presenterUid}',
          );
        }
      },
      child: LiquidGlass(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 头像 + 直播状态点
            Stack(
              children: [
                ClipOval(
                  child: room.streamerAvatar.isNotEmpty
                      ? Image.network(room.streamerAvatar, width: 48, height: 48, fit: BoxFit.cover)
                      : Container(
                          width: 48, height: 48,
                          color: const Color(0xFF2D2D44),
                          child: const Icon(Icons.person, color: Colors.white38),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: room.isLive ? const Color(0xFFFF6B6B) : const Color(0xFF666666),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.streamerName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.isLive ? room.title : '未开播',
                    style: TextStyle(
                      color: room.isLive ? Colors.white70 : Colors.white38,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 粉丝数
            Text(
              '粉丝 ${room.fansCount}',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
