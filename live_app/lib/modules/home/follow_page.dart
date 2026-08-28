import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../live_play/live_play_page.dart';
import 'follow_store.dart';

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
    _refresh();
  }

  /// 刷新：逐个核验开播状态并回写，用于分组
  Future<void> _refresh() async {
    final store = FollowStore.to;
    if (store.refreshing.value) return;
    store.refreshing.value = true;
    try {
      final snapshot = store.items.toList();
      for (final e in snapshot) {
        try {
          final info = await _resolver
              .resolveStream(e.roomId)
              .timeout(const Duration(seconds: 6));
          if (info != null) {
            final idx = store.items.indexWhere((x) => x.roomId == e.roomId);
            if (idx >= 0) {
              store.items[idx] = FollowItem(
                roomId: e.roomId,
                name: info.streamerInfo.nickname.isNotEmpty
                    ? info.streamerInfo.nickname
                    : e.name,
                avatar: info.streamerInfo.avatar.isNotEmpty
                    ? info.streamerInfo.avatar
                    : e.avatar,
                isLive: info.isLive,
              );
            }
          }
        } catch (_) {}
      }
      await store._save();
    } finally {
      store.refreshing.value = false;
    }
  }

  void _open(FollowItem it) =>
      Get.to(() => const LivePlayPage(), arguments: {'roomId': it.roomId});

  Future<void> _unfollow(FollowItem it) async {
    final ok = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title:
                const Text('取消订阅', style: TextStyle(color: Colors.white)),
            content: Text('不再关注「${it.name}」？',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('保留',
                      style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text('取消订阅',
                      style: TextStyle(color: Color(0xFFE5484D)))),
            ],
          ),
        ) ??
        false;
    if (ok) await FollowStore.remove(it.roomId);
  }

  /// 分组标题：纯色点 + 文字，不使用 emoji
  Widget _sectionHeader(String title, int count, Color dot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        const SizedBox(width: 6),
        Text('$title ($count)',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _tile(FollowItem it, bool live) {
    return GestureDetector(
      onTap: () => _open(it),
      onLongPress: () => _unfollow(it),
      child: GlassListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white10,
          backgroundImage: it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
          child: it.avatar.isEmpty
              ? const Icon(Icons.person, size: 22, color: Colors.white54)
              : null,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(it.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('房间 ${it.roomId}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        trailing: live
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0x33E5484D),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('直播中',
                    style: TextStyle(
                        color: Color(0xFFE5484D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              )
            : const Icon(Icons.chevron_right, color: Colors.white30),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: Text(text,
                style: const TextStyle(color: Colors.white38, fontSize: 13))),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final all = FollowStore.to.items.toList();
      final live = all.where((e) => e.isLive).toList();
      final offline = all.where((e) => !e.isLive).toList();
      return RefreshIndicator(
        color: const Color(0xFFFF8800),
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                size: 40,
                onPressed: _refresh,
              ),
            ]),
            const SizedBox(height: 8),
            GlassGroupedSection(
              header:
                  _sectionHeader('开播中', live.length, const Color(0xFFE5484D)),
              children: live.isEmpty
                  ? [_empty('暂无开播主播')]
                  : live.map((e) => _tile(e, true)).toList(),
            ),
            const SizedBox(height: 16),
            GlassGroupedSection(
              header: _sectionHeader('未开播', offline.length, Colors.white38),
              children: offline.isEmpty
                  ? [_empty('暂无未开播主播')]
                  : offline.map((e) => _tile(e, false)).toList(),
            ),
          ],
        ),
      );
    });
  }
}
