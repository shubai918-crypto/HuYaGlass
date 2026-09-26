import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_page.dart';
import 'history_store.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  String _ago(int ts) {
    final d = DateTime.now().millisecondsSinceEpoch - ts;
    if (d < 60000) return '刚刚';
    if (d < 3600000) return '${d ~/ 60000}分钟前';
    if (d < 86400000) return '${d ~/ 3600000}小时前';
    return '${d ~/ 86400000}天前';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('观看历史', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white70), onPressed: () => HistoryStore.clear()),
        ],
      ),
      body: Obx(() {
        if (HistoryStore.items.isEmpty) {
          return const Center(child: Text('暂无观看历史', style: TextStyle(color: Colors.white38)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: HistoryStore.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = HistoryStore.items[i];
            return GestureDetector(
              onTap: () => goLive(e.roomId, nickname: e.name, avatarUrl: e.avatar),
              onLongPress: () => HistoryStore.remove(e.roomId),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: Colors.white10,
                      backgroundImage: e.avatar.isNotEmpty ? NetworkImage(e.avatar) : null,
                      child: e.avatar.isEmpty ? const Icon(Icons.person, size: 20, color: Colors.white54) : null),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('房间 ${e.roomId} · ${_ago(e.ts)}', style: const TextStyle(color: Colors.white40, fontSize: 12)),
                  ])),
                  const Icon(Icons.chevron_right, color: Colors.white30),
                ]),
              ),
            );
          },
        );
      }),
    );
  }
}
