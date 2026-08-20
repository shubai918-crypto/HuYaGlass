import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import '../settings/huya_login_page.dart';
import 'follow_store.dart';

/// 主壳：官方示例同款 —— 玻璃导航层 + 不透明内容
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  static const _titles = ['HuyaLive', '搜索', '我的订阅', '设置'];

  @override
  Widget build(BuildContext context) {
    return AdaptiveLiquidGlassLayer(
      settings: const LiquidGlassSettings(),
      quality: GlassQuality.standard,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        appBar: GlassAppBar(
          title: Text(_titles[_tab]),
          actions: [
            GlassIconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () => Get.to(() => const HuyaLoginPage()),
            ),
          ],
        ),
        body: IndexedStack(
          children: const [
            _HomeView(),
            _SearchView(),
            _FollowsView(),
            _SettingsView(),
          ],
        ),
        // 底部胶囊玻璃标签栏（Apple Music 同款）
        bottomNavigationBar: GlassTabBar(
          tabs: const [
            GlassTab(icon: Icons.home_filled, label: '首页'),
            GlassTab(icon: Icons.search, label: '搜索'),
            GlassTab(icon: Icons.subscriptions_outlined, label: '订阅'),
            GlassTab(icon: Icons.settings, label: '设置'),
          ],
          selectedIndex: _tab,
          onTabSelected: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

// ================= 首页 Tab：Hero 大卡 + 入口 =================
class _HomeView extends StatelessWidget {
  const _HomeView();

  void _goLive(String roomId) {
    if (roomId.isEmpty) return;
    Get.toNamed('/live', parameters: {'roomId': roomId});
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
          TextButton(onPressed: () => Get.back(),
              child: const Text('取消', style: TextStyle(color: Colors.white54))),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero 大卡（不透明渐变，仿示例红色卡片）
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
                icon: Icons.play_arrow,
                label: '进入直播间',
                onTap: () => _openEnterRoom(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 不透明内容卡
        _ContentCard(
          icon: Icons.subscriptions_outlined,
          color: const Color(0xFFFF6B6B),
          label: '我的订阅',
          sub: '长按可移除订阅主播',
          onTap: () {},
          trailing: true,
        ),
        const SizedBox(height: 12),
        _ContentCard(
          icon: Icons.account_circle,
          color: const Color(0xFF7C6BFF),
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '登录后可发真实弹幕 / 看真实订阅数',
          onTap: () => Get.to(() => const HuyaLoginPage()),
          trailing: true,
        ),
      ],
    );
  }
}

/// 不透明内容卡片（黄金规则：内容不用玻璃）
class _ContentCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool trailing;
  const _ContentCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
    this.trailing = false,
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
            if (trailing) const Icon(Icons.chevron_right, color: Colors.white38),
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
      Get.toNamed('/live', parameters: {'roomId': k});
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
                child: GlassTextField(
                  placeholder: '搜索主播 / 输入房间号',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (v) => _kw = v,
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
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
                          onTap: () =>
                              Get.toNamed('/live', parameters: {'roomId': r['roomId']!}),
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
            onTap: () => Get.toNamed('/live', parameters: {'roomId': f.roomId}),
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
          trailing: true,
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
