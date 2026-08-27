import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../live_play/background_play.dart';
import '../live_play/live_play_page.dart';
import '../search/search_page.dart';
import '../settings/huya_login_page.dart';
import 'follow_store.dart';

/// 虎牙品牌橙
const Color kHuyaAccent = Color(0xFFFF8800);

class NowRoom {
  final String roomId;
  final String nickname;
  final String avatarUrl;
  const NowRoom(
      {required this.roomId, required this.nickname, this.avatarUrl = ''});
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

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        contentAwareBrightness: true,
        statusBarStyle: GlassStatusBarStyle.light,
        background: SizedBox.expand(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.8),
                radius: 1.6,
                colors: [
                  Color(0xFF2D1B4E),
                  Color(0xFF12121A),
                  Color(0xFF050508),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        appBar: GlassAppBar(
          title: GlassContainer(
            shape: const LiquidRoundedSuperellipse(borderRadius: 999),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            useOwnLayer: true,
            settings: LiquidGlassSettings(blur: 8, thickness: 20),
            child: const Text(
              'HuyaLive',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
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
        // ★ 1.0.0 统一导航：GlassTabBar.bottom() + GlassTab
        bottomBar: GlassTabBar.bottom(
          adaptiveBrightness: true,
          selectedIndex: _selectedIndex,
          onTabSelected: (i) => setState(() => _selectedIndex = i),
          selectedIconColor: kHuyaAccent,
          selectedLabelColor: kHuyaAccent,
          unselectedIconColor: Colors.white.withOpacity(0.5),
          unselectedLabelColor: Colors.white.withOpacity(0.5),
          indicatorColor: kHuyaAccent.withOpacity(0.15),
          settings: LiquidGlassSettings(
            blur: 24,
            thickness: 30,
            glassColor: Colors.black.withOpacity(0.35),
          ),
          bottomAccessory: _buildMiniBar(),
          bottomAccessoryHeight: 64,
          bottomAccessorySpacing: 8.0,
          tabs: const [
            GlassTab(icon: Icon(Icons.home), label: '首页'),
            GlassTab(icon: Icon(Icons.search), label: '搜索'),
            GlassTab(icon: Icon(Icons.subscriptions_outlined), label: '订阅'),
            GlassTab(icon: Icon(Icons.settings), label: '设置'),
          ],
        ),
        body: ValueListenableBuilder<NowRoom?>(
          valueListenable: NowWatching.notifier,
          builder: (context, room, _) => Padding(
            padding: EdgeInsets.only(
              top: topPad + 64,
              bottom: bottomPad + (room != null ? 170 : 100),
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeView(
                    onOpenFollows: () => setState(() => _selectedIndex = 2)),
                SearchPage(
                  onOpenRoom: (roomId, nickname, avatarUrl) => goLive(roomId,
                      nickname: nickname, avatarUrl: avatarUrl),
                  isFollowed: (roomId) async => FollowStore.contains(roomId),
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
        ),
      ),
    );
  }

  Widget _buildMiniBar() {
    return ValueListenableBuilder<NowRoom?>(
      valueListenable: NowWatching.notifier,
      builder: (context, room, _) {
        if (room == null) return const SizedBox.shrink();
        return GlassContainer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          useOwnLayer: true,
          settings: LiquidGlassSettings(
            blur: 20,
            thickness: 25,
            glassColor: const Color(0xFF1A1A24).withOpacity(0.6),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: room.avatarUrl.isNotEmpty
                    ? Image.network(room.avatarUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _artPlaceholder())
                    : _artPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(room.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const Text('正在播放 · 虎牙直播',
                        maxLines: 1,
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              GlassIconButton(
                icon: const Icon(Icons.play_arrow, color: kHuyaAccent),
                size: 36,
                onPressed: () => goLive(room.roomId,
                    nickname: room.nickname, avatarUrl: room.avatarUrl),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _artPlaceholder() => Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kHuyaAccent, Color(0xFFFF5A00)]),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.live_tv, size: 20, color: Colors.white),
      );
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
        title: const Text('进入直播间',
            style: TextStyle(color: Colors.white, fontSize: 16)),
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
              child:
                  const Text('取消', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Get.back();
              goLive(ctrl.text.trim());
            },
            child: const Text('进入', style: TextStyle(color: kHuyaAccent)),
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
              colors: [kHuyaAccent, Color(0xFFFF5A00)],
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
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('看直播 · 弹幕 · 订阅 · 真实发送',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 13)),
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
          color: kHuyaAccent,
          label: '我的订阅',
          sub: '点击查看已收藏的主播',
          onTap: onOpenFollows,
        ),
        const SizedBox(height: 12),
        _OpaqueContentCard(
          icon: Icons.account_circle,
          color: const Color(0xFFFFB25E),
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

// ================= 订阅 Tab（响应式 + 分组 + 刷新） =================
class _FollowsView extends StatefulWidget {
  const _FollowsView();
  @override
  State<_FollowsView> createState() => _FollowsViewState();
}

class _FollowsViewState extends State<_FollowsView> {
  final HuyaStreamResolver _resolver = HuyaStreamResolver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (FollowStore.instance.refreshing.value) return;
    FollowStore.instance.refreshing.value = true;
    try {
      for (final it in FollowStore.instance.items.toList()) {
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
      FollowStore.instance.refreshing.value = false;
    }
  }

  Widget _tile(FollowItem it) {
    return GestureDetector(
      onTap: () => goLive(it.roomId, nickname: it.name, avatarUrl: it.avatar),
      onLongPress: () async {
        await FollowStore.remove(it.roomId);
      },
      child: GlassListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white10,
          backgroundImage: it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _section(String title, List<FollowItem> list) {
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
          Obx(() => FollowStore.instance.refreshing.value
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kHuyaAccent))
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
      final all = FollowStore.instance.items.toList();
      final live = all.where((e) => e.isLive).toList();
      final offline = all.where((e) => !e.isLive).toList();

      if (all.isEmpty && !FollowStore.instance.refreshing.value) {
        return const Center(
          child: Text('暂无订阅主播\n在直播间点「订阅」即可收藏',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38)),
        );
      }

      return RefreshIndicator(
        color: kHuyaAccent,
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
                icon: const Icon(Icons.refresh, color: kHuyaAccent),
                size: 40,
                onPressed: _refresh,
              ),
            ]),
            const SizedBox(height: 12),
            _section('开播中 (${live.length})', live),
            _section('未开播 (${offline.length})', offline),
          ],
        ),
      );
    });
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
        _OpaqueContentCard(
          icon: Icons.account_circle,
          color: kHuyaAccent,
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '粘贴 Cookie 登录，解锁真实弹幕与订阅数',
          onTap: () => Get.to(() => const HuyaLoginPage()),
        ),
        const SizedBox(height: 12),
        _OpaqueContentCard(
          icon: Icons.battery_charging_full,
          color: const Color(0xFF7ED97E),
          label: '允许应用后台运行',
          sub: '弹出系统授权对话框（后台播放必开）',
          onTap: () => BackgroundPlayStore.requestBatteryWhitelist(),
        ),
        const SizedBox(height: 12),
        _OpaqueContentCard(
          icon: Icons.info_outline,
          color: Colors.white70,
          label: '关于',
          sub: 'HuyaLive · 液态玻璃 1.0.0 · 参考 pure_live / dtv',
          onTap: () {},
        ),
      ],
    );
  }
}
