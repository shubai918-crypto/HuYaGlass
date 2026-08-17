import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/liquid_glass.dart';
import '../../app/routes.dart';
import 'search_controller.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SearchController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索直播间'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: LiquidGlass(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: controller.searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '搜索主播或直播间...',
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () {
                      controller.searchController.clear();
                      controller.results.clear();
                    },
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (text) => controller.search(text),
              ),
            ),
          ),

          // 搜索结果
          Expanded(
            child: Obx(() {
              if (controller.searching.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.results.isEmpty) {
                return Center(
                  child: Text(
                    controller.hasSearched.value ? '没有找到结果' : '输入关键词搜索',
                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.results.length,
                itemBuilder: (context, index) {
                  final room = controller.results[index];
                  return _RoomCard(room: room);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final LiveRoom room;

  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(
          '${AppRoutes.livePlay}?roomId=${room.roomId}&uid=${room.presenterUid}',
        );
      },
      child: LiquidGlass(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: room.coverUrl.isNotEmpty
                  ? Image.network(
                      room.coverUrl,
                      width: 120,
                      height: 68,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 120,
                      height: 68,
                      color: const Color(0xFF2D2D44),
                    ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.streamerName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (room.isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '直播中',
                            style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        '粉丝 ${room.fansCount}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
