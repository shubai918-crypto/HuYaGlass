import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../live_play/live_play_page.dart';
import 'follow_store.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (FollowStore.to.refreshing.value) return;
    FollowStore.to.refreshing.value = true;
    try {
      await FollowStore.to.refresh();
    } finally {
      FollowStore.to.refreshing.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final all = FollowStore.to.items.toList();
      
      if (all.isEmpty && !FollowStore.to.refreshing.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.subscriptions_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 12),
              const Text('暂无订阅', style: TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 24),
              GlassButton(
                icon: const Icon(Icons.refresh),
                label: '刷新',
                onTap: _refresh, 
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFFF8800),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: all.length,
          itemBuilder: (_, i) {
            final it = all[i];
            return GestureDetector(
              onTap: () {
                // ★ 修复：GetX 传参使用 arguments
                Get.to(() => const LivePlayPage(), arguments: {'roomId': it.roomId});
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white10,
                      backgroundImage: it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
                      child: it.avatar.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        it.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ★ 修复：GlassIconButton 1.1.0 使用 onPressed
                    GlassIconButton(
                      icon: const Icon(Icons.play_arrow, color: Color(0xFFFF8800)),
                      size: 40,
                      onPressed: () {
                        Get.to(() => const LivePlayPage(), arguments: {'roomId': it.roomId});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
