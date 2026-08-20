import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../live_play/live_play_page.dart';
import '../settings/settings_page.dart';
import 'follow_store.dart';

/// 首页：玻璃仅用于导航层（AppBar/卡片控件），内容保持不透明
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _goLive(String roomId) {
    if (roomId.isEmpty) return;
    Get.to(() => const LivePlayPage(), parameters: {'roomId': roomId});
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161622), Color(0xFF0A0A0F)],
          ),
        ),
      ),
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        title: const Text('HuyaLive'),
        actions: [
          GlassIconButton(
            icon: const Icon(Icons.settings),
            onTap: () => Get.to(() => const SettingsPage()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            _EntryCard(
              icon: Icons.search,
              color: const Color(0xFF00D2FF),
              label: '搜索直播间',
              onTap: () => _openSearch(context),
            ),
            const SizedBox(height: 12),
            _EntryCard(
              icon: Icons.subscriptions_outlined,
              color: const Color(0xFFFF6B6B),
              label: '我的订阅',
              onTap: () => _openFollows(context),
            ),
            const SizedBox(height: 12),
            _EntryCard(
              icon: Icons.play_circle_outline,
              color: const Color(0xFF7C6BFF),
              label: '进入直播间',
              onTap: () => _openEnterRoom(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SearchSheet(),
    );
  }

  void _openFollows(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FollowsSheet(),
    );
  }

  void _openEnterRoom(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('进入直播间', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '输入房间号，如 31343932',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _goLive(ctrl.text.trim());
            },
            child: const Text('进入', style: TextStyle(color: Color(0xFF00D2FF))),
          ),
        ],
      ),
    );
  }
}

/// 导航入口卡片（玻璃控件层）
class _EntryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _EntryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

/// 搜索抽屉：主播名走虎牙搜索接口，纯数字直接进房间
class _SearchSheet extends StatefulWidget {
  const _SearchSheet();
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  List<Map<String, String>> _results = [];

  Future<void> _search(String kw) async {
    final k = kw.trim();
    if (k.isEmpty) return;
    if (RegExp(r'^\d+$').hasMatch(k)) {
      Get.back();
      Get.to(() => const LivePlayPage(), parameters: {'roomId': k});
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await http
          .get(Uri.parse(
            'https://search.cdn.huya.com/websearch?platform=b2&src=huya&keyword=${Uri.encodeComponent(k)}&page=1&rows=20',
          ))
          .timeout(const Duration(seconds: 6));
      final j = jsonDecode(res.body);
      final docs = (j['response']?['1']?['docs'] as List?) ??
          (j['data']?['docs'] as List?) ??
          const [];
      setState(() {
        _results = docs
            .map((e) {
              final m = e as Map<String, dynamic>;
              return {
                'name': '${m['game_nick'] ?? m['nick'] ?? ''}',
                'roomId': '${m['room_id'] ?? m['roomId'] ?? ''}',
                'game': '${m['game_short_name'] ?? m['gameName'] ?? ''}',
              };
            })
            .where((e) => e['roomId']!.isNotEmpty)
            .toList();
      });
    } catch (_) {
      setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '搜索主播 / 直接输入房间号',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF00D2FF)),
                ),
                onSubmitted: _search,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _busy
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00D2FF)))
                  : _results.isEmpty
                      ? const Center(
                          child: Text('暂无结果（可直接输入房间号进入）',
                              style: TextStyle(color: Colors.white24)))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (c, i) {
                            final r = _results[i];
                            return ListTile(
                              title: Text(r['name']!,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${r['game']} · 房间 ${r['roomId']}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                              onTap: () {
                                Get.back();
                                Get.to(() => const LivePlayPage(),
                                    parameters: {'roomId': r['roomId']!});
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 我的订阅抽屉：长按移除
class _FollowsSheet extends StatefulWidget {
  const _FollowsSheet();
  @override
  State<_FollowsSheet> createState() => _FollowsSheetState();
}

class _FollowsSheetState extends State<_FollowsSheet> {
  List<FollowItem> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await FollowStore.all();
    if (mounted) setState(() => _list = list);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: _list.isEmpty
          ? const Center(
              child: Text('暂无订阅主播', style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              itemCount: _list.length,
              itemBuilder: (c, i) {
                final f = _list[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2D2D44),
                    backgroundImage:
                        f.avatar.isNotEmpty ? NetworkImage(f.avatar) : null,
                    child: f.avatar.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
                  ),
                  title: Text(f.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('房间 ${f.roomId}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  onTap: () {
                    Get.back();
                    Get.to(() => const LivePlayPage(),
                        parameters: {'roomId': f.roomId});
                  },
                  onLongPress: () async {
                    await FollowStore.remove(f.roomId);
                    _load();
                  },
                );
              },
            ),
    );
  }
}
