import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import '../live_play/live_play_page.dart';
import '../settings/huya_login_page.dart';
import 'follow_store.dart';

/// 进入直播间（arguments 传参，不依赖路由表）
void goLive(String roomId) {
  if (roomId.isEmpty) return;
  Get.to(() => const LivePlayPage(), arguments: {'roomId': roomId});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      type: MaterialType.transparency, // 消除黄下划线
      child: GlassScaffold(
        // 玻璃折射背景
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF161622), Color(0xFF0A0A0F)],
            ),
          ),
        ),
        statusBarStyle: GlassStatusBarStyle.light,
        appBar: GlassAppBar(
          title: const Text('HuyaLive'),
          actions: [
            GlassIconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () => Get.to(() => const HuyaLoginPage()),
            ),
          ],
        ),
        bottomBar: GlassTabBar.bottom(
          selectedIndex: _selectedIndex,
          onTabSelected: (i) => setState(() => _selectedIndex = i),
          tabs: const [
            GlassTab(icon: Icon(Icons.home), label: '首页'),
            GlassTab(icon: Icon(Icons.search), label: '搜索'),
            GlassTab(icon: Icon(Icons.subscriptions_outlined), label: '订阅'),
            GlassTab(icon: Icon(Icons.settings), label: '设置'),
          ],
        ),
        // 关键：GlassScaffold 的栏是悬浮层，body 需手动留出上下空间
        body: Padding(
          padding: EdgeInsets.only(
            top: topPad + 64,
            bottom: bottomPad + 88,
          ),
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _HomeView(
                onOpenFollows: () => setState(() => _selectedIndex = 2),
              ),
              const _SearchView(),
              const _FollowsView(),
              const _SettingsView(),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 首页 Tab =================
class _HomeView extends StatelessWidget {
  final VoidCallback onOpenFollows;
  const _HomeView({required this.onOpenFollows});

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
          TextButton(onPressed: () => Get.back(),
              child: const Text('取消', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Get.back();
              goLive(ctrl.text.trim());
            },
            child: const Text('进入', style: TextStyle(color: Color(0xFF00D2FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D2FF), Color(0xFF7C6BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Icon(Icons.live_tv, size: 56, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                '虎牙直播 · 液态玻璃',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '看直播 · 弹幕 · 订阅 · 真实发送',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
              ),
              const SizedBox(height: 18),
              GlassButton(
                icon: const Icon(Icons.play_arrow),
                label: '进入直播间',
                onTap: () => _openEnterRoom(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ContentCard(
          icon: Icons.subscriptions_outlined,
          color: const Color(0xFFFF6B6B),
          label: '我的订阅',
          sub: '点击查看已收藏的主播',
          onTap: onOpenFollows,
        ),
        const SizedBox(height: 12),
        _ContentCard(
          icon: Icons.account_circle,
          color: const Color(0xFF7C6BFF),
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '登录后可发真实弹幕 / 看真实订阅数',
          onTap: () => Get.to(() => const HuyaLoginPage()),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ContentCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ================= 搜索 Tab =================
class _SearchView extends StatefulWidget {
  const _SearchView();
  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  String _kw = '';
  bool _busy = false;
  List<Map<String, String>> _results = [];

  Future<void> _search() async {
    final k = _kw.trim();
    if (k.isEmpty) return;
    if (RegExp(r'^\d+$').hasMatch(k)) {
      goLive(k);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '搜索主播 / 输入房间号',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Color(0xFF00D2FF)),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => _kw = v,
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF00D2FF)),
                onPressed: _search,
              ),
            ],
          ),
        ),
        Expanded(
          child: _busy
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D2FF)))
              : _results.isEmpty
                  ? const Center(
                      child: Text('搜索主播，或直接输入房间号进入',
                          style: TextStyle(color: Colors.white24)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (c, i) {
                        final r = _results[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2D2D44),
                            child: Text(
                              r['name']!.isNotEmpty ? r['name']![0] : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(r['name']!, style: const TextStyle(color: Colors.white)),
                          subtitle: Text('${r['game']} · 房间 ${r['roomId']}',
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          onTap: () => goLive(r['roomId']!),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ================= 订阅 Tab =================
class _FollowsView extends StatefulWidget {
  const _FollowsView();
  @override
  State<_FollowsView> createState() => _FollowsViewState();
}

class _FollowsViewState extends State<_FollowsView> {
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
    if (_list.isEmpty) {
      return const Center(
          child: Text('暂无订阅主播\n在直播间点「订阅」即可收藏',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _list.length,
      itemBuilder: (c, i) {
        final f = _list[i];
        return Card(
          color: const Color(0xFF16161E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2D2D44),
              backgroundImage: f.avatar.isNotEmpty ? NetworkImage(f.avatar) : null,
              child: f.avatar.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
            ),
            title: Text(f.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('房间 ${f.roomId}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () => goLive(f.roomId),
            onLongPress: () async {
              await FollowStore.remove(f.roomId);
              _load();
            },
          ),
        );
      },
    );
  }
}

// ================= 设置 Tab =================
class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ContentCard(
          icon: Icons.account_circle,
          color: const Color(0xFF00D2FF),
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '粘贴 Cookie 登录，解锁真实弹幕与订阅数',
          onTap: () => Get.to(() => const HuyaLoginPage()),
        ),
        const SizedBox(height: 12),
        _ContentCard(
          icon: Icons.info_outline,
          color: const Color(0xFF7C6BFF),
          label: '关于',
          sub: 'HuyaLive · 液态玻璃版 · 参考 pure_live / dtv',
          onTap: () {},
        ),
      ],
    );
  }
}
