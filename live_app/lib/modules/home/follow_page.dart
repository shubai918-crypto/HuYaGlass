import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import 'follow_store.dart';
import '../live_play/live_play_page.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  final HuyaStreamResolver _resolver = HuyaStreamResolver();

  @override
  void initState() {
    super.initState();
    // 进入页面自动核验一次开播状态
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (FollowStore.refreshing.value) return;
    FollowStore.refreshing.value = true;
    try {
      for (final it in FollowStore.items.toList()) {
        try {
          final info = await _resolver
              .resolveStream(it.roomId)
              .timeout(const Duration(seconds: 8));
          if (info != null) {
            FollowStore.updateLive(
              it.roomId,
              info.isLive,
              name: info.streamerInfo.nickname.isNotEmpty
                  ? info.streamerInfo.nickname
                  : null,
              avatar: info.streamerInfo.avatar.isNotEmpty
                  ? info.streamerInfo.avatar
                  : null,
            );
          }
        } catch (_) {}
      }
    } finally {
      FollowStore.refreshing.value = false;
    }
  }

  void _open(FollowItem it) {
    Get.to(() => const LivePlayPage(), parameters: {'roomId': it.roomId});
  }

  void _confirmRemove(FollowItem it) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('取消订阅', style: TextStyle(color: Colors.white)),
        content: Text('不再关注「${it.name}」？',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('保留',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () {
                FollowStore.remove(it.roomId);
                Get.back();
              },
              child: const Text('取消订阅',
                  style: TextStyle(color: Color(0xFFE5484D)))),
        ],
      ),
    );
  }

  Widget _tile(FollowItem it) {
    return GestureDetector(
      onTap: () => _open(it),
      onLongPress: () => _confirmRemove(it),
      child: GlassListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white10,
          backgroundImage:
              it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
          child: it.avatar.isEmpty
              ? const Icon(Icons.person, color: Colors.white54, size: 22)
              : null,
        ),
        title: Text(it.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        subtitle: Text('房间 ${it.roomId}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: it.isLive
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0x33E5484D),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('直播中',
                    style: TextStyle(
                        color: Color(0xFFE5484D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              )
            : GlassListTile.chevron,
      ),
    );
  }

  Widget _section(String title, List<FollowItem> list, String emptyText) {
    return GlassGroupedSection(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Obx(() => FollowStore.refreshing.value
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFF8800)))
              : const SizedBox.shrink()),
        ]),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      children: list.isEmpty
          ? [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                    child: Text('暂无数据',
                        style: TextStyle(color: Colors.white38))),
              ),
            ]
          : list.map(_tile).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final all = FollowStore.items.toList();
      final live = all.where((e) => e.isLive).toList();
      final offline = all.where((e) => !e.isLive).toList();
      return RefreshIndicator(
        color: const Color(0xFFFF8800),
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Row(children: [
              const Text('我的订阅',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GlassIconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFFF8800)),
                onTap: _refresh,
              ),
            ]),
            const SizedBox(height: 12),
            _section('开播主播 (${live.length})', live, '暂无开播'),
            _section('未开播主播 (${offline.length})', offline, '暂无未开播'),
          ],
        ),
      );
    });
  }
}
