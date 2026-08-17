import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/liquid_glass.dart';
import '../../app/routes.dart';
import 'follow_controller.dart';

/// 关注/订阅页面（参考 dtv_mobile FollowScreen）
class FollowPage extends StatelessWidget {
  const FollowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FollowController());

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('我的订阅', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value && controller.followedList.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
          );
        }

        if (controller.followedList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subscriptions_outlined,
                  size: 72,
                  color: Colors.white.withOpacity(0.15),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无订阅主播',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '搜索直播间并订阅你喜爱的主播',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF00D2FF),
          onRefresh: () => controller.refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.followedList.length,
            itemBuilder: (context, index) {
              final room = controller.followedList[index];
              return _FollowItemCard(
                room: room,
                onRemove: () => controller.removeFollow(room),
              );
            },
          ),
        );
      }),
    );
  }
}

class _FollowItemCard extends StatelessWidget {
  final LiveRoom room;
  final VoidCallback onRemove;

  const _FollowItemCard({required this.room, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(room.roomId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
      ),
      child: GestureDetector(
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
              // 头像 + 直播状态指示灯
              Stack(
                children: [
                  ClipOval(
                    child: room.streamerAvatar.isNotEmpty
                        ? Image.network(
                            room.streamerAvatar,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 48,
                            height: 48,
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
                        color: room.isLive
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF555555),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0A0A0F), width: 2),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      room.isLive ? '直播中' : '未开播',
                      style: TextStyle(
                        color: room.isLive
                            ? const Color(0xFFFF6B6B)
                            : Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // 粉丝数
              if (room.fansCount > 0)
                Text(
                  '粉丝 ${_formatCount(room.fansCount)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(width: 8),
              // 箭头
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.2),
                size: 20,
              ),
            ],
          ),
        ),
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
