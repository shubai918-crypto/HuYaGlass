import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import '../live_play/background_play.dart';
import '../live_play/live_play_page.dart';
import '../search/search_page.dart';
import '../settings/huya_login_page.dart';
import 'follow_store.dart';

class NowRoom {
  final String roomId;
  final String nickname;
  final String avatarUrl;
  const NowRoom({required this.roomId, required this.nickname, this.avatarUrl = ''});
}

class NowWatching {
  static final ValueNotifier<NowRoom?> notifier = ValueNotifier(null);
}

void goLive(String roomId, {String nickname = '', String avatarUrl = ''}) {
  if (roomId.isEmpty) return;
  NowWatching.notifier.value = NowRoom(
    roomId: roomId,
    nickname: nickname.isEmpty ? '虎牙主播' : nickname,
    avatarUrl: avatarUrl,
  );
  Get.to(() => const LivePlayPage(), arguments: {'roomId': roomId});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0A2E), Color(0xFF1A0A3E), Color(0xFF0D1B2A)],
            ),
          ),
        ),
        statusBarStyle: GlassStatusBarStyle.light,
        appBar: GlassAppBar(
          title: GlassContainer(
            shape: const LiquidRoundedSuperellipse(borderRadius: 999),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            useOwnLayer: true,
            settings: LiquidGlassSettings(blur: 8, thickness: 20),
            child: const Text(
              'HuyaLive',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          actions: [
            GlassIconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              size: 44,
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
          ],
        ),
        bottomBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _compact ? _buildCompactBar() : _buildFullBar(),
        ),
        body: Padding(
          padding: EdgeInsets.only(
            top: topPad + 64,
            bottom: bottomPad + (_compact ? 64 : 88),
          ),
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _HomeView(onOpenFollows: () => setState(() => _selectedIndex = 2)),
                    SearchPage(
                      onOpenRoom: (roomId, nickname, avatarUrl) =>
                          goLive(roomId, nickname: nickname, avatarUrl: avatarUrl),
                      isFollowed: (roomId) => FollowStore.contains(roomId),
                      onToggleFollow: (roomId, follow, nickname, avatar) async {
                        if (follow) {
                          await FollowStore.add(FollowItem(
                              roomId: roomId, name: nickname, avatar: avatar));
                        } else {
                          await FollowStore.remove(roomId);
                        }
                      },
                    ),
                    const _FollowsView(),
                    const _SettingsView(),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 8,
                child: ValueListenableBuilder<NowRoom?>(
                  valueListenable: NowWatching.notifier,
                  builder: (context, room, _) =>
                      room == null ? const SizedBox.shrink() : _MiniBar(room: room),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      final pixels = n.metrics.pixels;
      if (delta > 0 && pixels > 80 && !_compact) {
        setState(() => _compact = true);
      } else if ((delta < 0 || pixels <= 0) && _compact) {
        setState(() => _compact = false);
      }
    }
    return false;
  }

  // ★ 修复：icon 参数必须传入 Widget (使用 Icon 包裹)
  Widget _buildFullBar() {
    return GlassTabBar.bottom(
      key: const ValueKey('full'),
      selectedIndex: _selectedIndex,
      onTabSelected: (i) => setState(() => _selectedIndex = i),
      tabs: const [
        GlassTab(icon: Icon(Icons.home), label: '首页'),
        GlassTab(icon: Icon(Icons.search), label: '搜索'),
        GlassTab(icon: Icon(Icons.subscriptions_outlined), label: '订阅'),
        GlassTab(icon: Icon(Icons.settings), label: '设置'),
      ],
    );
  }

  Widget _buildCompactBar() {
    return GlassTabBar.bottom(
      key: const ValueKey('compact'),
      selectedIndex: _selectedIndex,
      onTabSelected: (i) => setState(() => _selectedIndex = i),
      tabs: const [
        GlassTab(icon: Icon(Icons.home)),
        GlassTab(icon: Icon(Icons.search)),
        GlassTab(icon: Icon(Icons.subscriptions_outlined)),
        GlassTab(icon: Icon(Icons.settings)),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  final NowRoom room;
  const _MiniBar({required this.room});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      shape: const LiquidRoundedSuperellipse(borderRadius: 22),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      useOwnLayer: true,
      settings: LiquidGlassSettings(blur: 10, thickness: 30),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: room.avatarUrl.isNotEmpty
                ? Image.network(room.avatarUrl, width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _artPlaceholder())
                : _artPlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(room.nickname, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const Text('正在观看 · 点击回到直播', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          GlassIconButton(
            icon: const Icon(Icons.play_arrow, color: Color(0xFF00D2FF)),
            size: 40,
            onPressed: () => goLive(room.roomId, nickname: room.nickname, avatarUrl: room.avatarUrl),
          ),
          const SizedBox(width: 4),
          GlassIconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
            size: 36,
            onPressed: () => NowWatching.notifier.value = null,
          ),
        ],
      ),
    );
  }

  Widget _artPlaceholder() => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF00D2FF), Color(0xFF7C6BFF)]),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: const Icon(Icons.live_tv, size: 20, color: Colors.white),
      );
}

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
              const Text('虎牙直播 · 液态玻璃',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('看直播 · 弹幕 · 订阅 · 真实发送',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
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
        _OpaqueContentCard(
          icon: Icons.subscriptions_outlined,
          color: const Color(0xFFFF6B6B),
          label: '我的订阅',
          sub: '点击查看已收藏的主播',
          onTap: onOpenFollows,
        ),
        const SizedBox(height: 12),
        _OpaqueContentCard(
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

class _OpaqueContentCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _OpaqueContentCard({
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
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 12)),
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
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _list.length,
      itemBuilder: (c, i) {
        final f = _list[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => goLive(f.roomId, nickname: f.name, avatarUrl: f.avatar),
            onLongPress: () async {
              await FollowStore.remove(f.roomId);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white10,
                    backgroundImage:
                        f.avatar.isNotEmpty ? NetworkImage(f.avatar) : null,
                    child: f.avatar.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('房间 ${f.roomId}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _OpaqueContentCard(
          icon: Icons.account_circle,
          color: const Color(0xFF00D2FF),
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '粘贴 Cookie 登录，解锁真实弹幕与订阅数',
          onTap: () => Get.to(() => const HuyaLoginPage()),
        ),
        _OpaqueContentCard(
  icon: Icons.battery_charging_full,
  color: const Color(0xFF7ED97E),
  label: '允许应用后台运行',
  sub: '弹出系统授权对话框（ColorOS/MIUI 后台播放必开）',
  onTap: () => BackgroundPlayStore.requestBatteryWhitelist(),
),
        const SizedBox(height: 12),
        _OpaqueContentCard(
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
