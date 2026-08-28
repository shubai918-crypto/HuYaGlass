import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../live_play/live_play_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import 'follow_page.dart';
import 'follow_store.dart';

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
  final ValueNotifier<bool> _barMinimized = ValueNotifier(false);

  @override
  void dispose() {
    _barMinimized.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() {
      _selectedIndex = i;
      _barMinimized.value = false;
    });
  }

  /// 搜索(1)/订阅(2) 下滑超阈值收拢，上滑/回顶展开
  bool _onScroll(ScrollNotification n) {
    if (_selectedIndex != 1 && _selectedIndex != 2) return false;
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0.0;
      final pixels = n.metrics.pixels;
      if (delta > 0 && pixels > 120) {
        if (!_barMinimized.value) _barMinimized.value = true;
      } else if (delta < 0) {
        if (_barMinimized.value) _barMinimized.value = false;
      }
    } else if (n is ScrollEndNotification) {
      if (n.metrics.pixels < 40 && _barMinimized.value) {
        _barMinimized.value = false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      type: MaterialType.transparency, // ★ 关键：提供文本样式环境，去掉黄色双下划线
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
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          actions: [
            GlassIconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              size: 44,
              onPressed: () => _select(3),
            ),
          ],
        ),
        bottomBar: ValueListenableBuilder<bool>(
          valueListenable: _barMinimized,
          builder: (context, minimized, _) => AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: minimized
                ? _compactBar(bottomPad)
                : _expandedBar(bottomPad),
          ),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Padding(
            padding: EdgeInsets.only(top: topPad + 64),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeView(onOpenFollows: () => _select(2)),
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
                const FollowPage(),
                const SettingsPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 展开态：Mini 条 + 带标签 Tab ----------
  Widget _expandedBar(double bottomPad) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad + 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _buildMiniBar(),
          ),
          _buildTabBar(),
        ],
      ),
    );
  }

  // ---------- 收拢态：圆形图标 + 中间 Mini 条 ----------
  Widget _compactBar(double bottomPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPad + 6),
      child: Row(
        children: [
          _circleTab(0, Icons.home),
          const SizedBox(width: 8),
          _circleTab(1, Icons.search),
          const SizedBox(width: 8),
          Expanded(child: _buildMiniBar()),
          const SizedBox(width: 8),
          _circleTab(2, Icons.subscriptions_outlined),
          const SizedBox(width: 8),
          _circleTab(3, Icons.settings),
        ],
      ),
    );
  }

  Widget _circleTab(int index, IconData icon) {
    final selected = _selectedIndex == index;
    return GlassIconButton(
      icon: Icon(icon,
          color: selected ? kHuyaAccent : Colors.white.withOpacity(0.5),
          size: 22),
      size: 46,
      onPressed: () => _select(index),
    );
  }

  Widget _buildTabBar() {
    return GlassTabBar.bottom(
      adaptiveBrightness: true,
      selectedIndex: _selectedIndex,
      onTabSelected: _select,
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
      tabs: const [
        GlassTab(icon: Icon(Icons.home), label: '首页'),
        GlassTab(icon: Icon(Icons.search), label: '搜索'),
        GlassTab(icon: Icon(Icons.subscriptions_outlined), label: '订阅'),
        GlassTab(icon: Icon(Icons.settings), label: '设置'),
      ],
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
                        width: 40, height: 40, fit: BoxFit.cover,
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
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
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
        _card(
          icon: Icons.subscriptions_outlined,
          color: kHuyaAccent,
          label: '我的订阅',
          sub: '点击查看已收藏的主播',
          onTap: onOpenFollows,
        ),
        const SizedBox(height: 12),
        _card(
          icon: Icons.account_circle,
          color: const Color(0xFFFFB25E),
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '登录后可发真实弹幕 / 看真实订阅数',
          onTap: () => Get.toNamed('/huya_login'),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
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
}
