import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/app_settings.dart';

import '../live_play/live_play_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import 'follow_page.dart';
import 'follow_store.dart';
import 'history_store.dart';
import 'profile_page.dart';

// ★ 浅色色板（酷安式白底 + 虎牙橙）
const kBg = Color(0xFFF4F5F6);
const kCard = Colors.white;
const kText = Color(0xFF1F2329);
const kSub = Color(0xFF8A9099);
const kLine = Color(0xFFE9EBEF);
const kAccent = Color(0xFFFF8800);

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
  bool _isMinimized = false;
  double _lastScrollOffset = 0;

  void _select(int i) => setState(() => _selectedIndex = i);

  @override
  void initState() {
    super.initState();
    HistoryStore.init();
    ProfilePage.onJumpTab = _select;
    NowWatching.notifier.addListener(_onNowWatching);
  }

  void _onNowWatching() {
    final r = NowWatching.notifier.value;
    if (r != null) HistoryStore.add(r.roomId, r.nickname, r.avatarUrl);
  }

  @override
  void dispose() {
    NowWatching.notifier.removeListener(_onNowWatching);
    ProfilePage.onJumpTab = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final cur = notification.metrics.pixels;
          if (cur > _lastScrollOffset + 10 && cur > 40) {
            if (!_isMinimized) setState(() => _isMinimized = true);
          } else if (cur < _lastScrollOffset - 10 || cur <= 0) {
            if (_isMinimized) setState(() => _isMinimized = false);
          }
          _lastScrollOffset = cur;
        }
        return false;
      },
      child: ValueListenableBuilder<NowRoom?>(
        valueListenable: NowWatching.notifier,
        builder: (context, room, _) => Material(
          type: MaterialType.transparency,
          child: GlassScaffold(
            contentAwareBrightness: true,
            statusBarStyle: GlassStatusBarStyle.dark,
            background: const SizedBox.expand(child: ColoredBox(color: kBg)),
            appBar: GlassAppBar(
              title: GlassContainer(
                shape: const LiquidRoundedSuperellipse(borderRadius: 999),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                useOwnLayer: true,
                quality: GlassQuality.premium,
                settings: LiquidGlassSettings(
                  glassColor: const Color(0xB3FFFFFF),
                  thickness: 25, blur: 12, lightIntensity: 0.6,
                  specularSharpness: GlassSpecularSharpness.medium,
                  fresnelStrength: 1.0, saturation: 1.3, refractiveIndex: 1.15,
                ),
                child: const Text('HuyaLive',
                    style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              actions: [
                Obx(() => GlassIconButton(
                      icon: Icon(
                        AppSettings.to.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        color: const Color(0xFF3C4248),
                      ),
                      size: 44,
                      glowColor: kAccent.withOpacity(0.35),
                      onPressed: () => AppSettings.to.toggleTheme(),
                    )),
                GlassIconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFF3C4248)),
                  size: 44,
                  glowColor: kAccent.withOpacity(0.35),
                  onPressed: () => _showQuickSettings(context),
                ),
              ],
            ),
            body: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                bottom: 150,
              ),
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _HomeView(onOpenFollows: () => _select(2)),
                  SearchPage(
                    onOpenRoom: (roomId, nickname, avatarUrl) =>
                        goLive(roomId, nickname: nickname, avatarUrl: avatarUrl),
                    isFollowed: (roomId) async => FollowStore.contains(roomId),
                    onToggleFollow: (roomId, follow, nickname, avatar) async {
                      if (follow) {
                        await FollowStore.add(FollowItem(roomId: roomId, name: nickname, avatar: avatar));
                      } else {
                        await FollowStore.remove(roomId);
                      }
                    },
                  ),
                  const FollowPage(),
                  const ProfilePage(),
                ],
              ),
            ),
            bottomBar: GlassTabBar.minimizable(
              minimized: _isMinimized,
              onMinimizedTabTap: () => setState(() => _isMinimized = false),
              bottomAccessory: room != null ? _buildMiniBar(room) : null,
              bottomAccessoryHeight: room != null ? 56 : null,
              bottomAccessorySpacing: 8,
              settings: LiquidGlassSettings(
                glassColor: const Color(0xB3FFFFFF),
                thickness: 28, blur: 14, lightIntensity: 0.6,
                specularSharpness: GlassSpecularSharpness.medium,
                fresnelStrength: 1.0, saturation: 1.3, refractiveIndex: 1.15,
              ),
              barHeight: 64,
              minimizedBarHeight: 50,
              horizontalPadding: 16,
              verticalPadding: 10,
              spacing: 6,
              selectedIndex: _selectedIndex,
              onTabSelected: _select,
              indicatorColor: kAccent.withOpacity(0.12),
              selectedIconColor: kAccent,
              selectedLabelColor: kAccent,
              unselectedIconColor: const Color(0xFF5F6672),
              unselectedLabelColor: const Color(0xFF5F6672),
              iconSize: 26,
              labelFontSize: 10,
              iconLabelSpacing: 2,
              quality: GlassQuality.premium,
              interactionBehavior: GlassInteractionBehavior.full,
              tabs: const [
                GlassTab(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首页'),
                GlassTab(icon: Icon(Icons.search), label: '搜索'),
                GlassTab(icon: Icon(Icons.subscriptions_outlined), activeIcon: Icon(Icons.subscriptions), label: '订阅'),
                GlassTab(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFD8DBE0), borderRadius: BorderRadius.circular(2))),
            Obx(() => SwitchListTile(
                  secondary: const Icon(Icons.dark_mode, color: Color(0xFF3C4248)),
                  title: const Text('深色模式', style: TextStyle(color: kText, fontSize: 15)),
                  value: AppSettings.to.isDark, onChanged: (_) => AppSettings.to.toggleTheme(),
                )),
            Obx(() => SwitchListTile(
                  secondary: const Icon(Icons.bug_report_outlined, color: Color(0xFF3C4248)),
                  title: const Text('调试模式', style: TextStyle(color: kText, fontSize: 15)),
                  value: AppSettings.to.debugEnabled.value, onChanged: AppSettings.to.setDebug,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _buildMiniBar(NowRoom room) {
    return Builder(builder: (context) {
      final inline = GlassTabBarAccessoryPlacementScope.of(context) ==
          GlassTabBarAccessoryPlacement.inline;
      final avatarSize = inline ? 32.0 : 40.0;
      return GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 999),
        padding: EdgeInsets.symmetric(horizontal: inline ? 10 : 12, vertical: 4),
        useOwnLayer: true,
        quality: GlassQuality.premium,
        settings: LiquidGlassSettings(
          glassColor: const Color(0xCCFFFFFF),
          thickness: 25, blur: 12, lightIntensity: 0.6,
          specularSharpness: GlassSpecularSharpness.medium, saturation: 1.3,
        ),
        child: SizedBox(
          height: 48,
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: room.avatarUrl.isNotEmpty
                  ? Image.network(room.avatarUrl,
                      width: avatarSize, height: avatarSize, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _artPlaceholder(avatarSize))
                  : _artPlaceholder(avatarSize),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(room.nickname,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (!inline)
                    const Text('正在播放 · 虎牙直播',
                        maxLines: 1, style: TextStyle(color: kSub, fontSize: 10)),
                ],
              ),
            ),
            GlassIconButton(
              icon: const Icon(Icons.play_arrow, color: kAccent),
              size: inline ? 32 : 36,
              onPressed: () => goLive(room.roomId, nickname: room.nickname, avatarUrl: room.avatarUrl),
            ),
            const SizedBox(width: 4),
            GlassIconButton(
              icon: const Icon(Icons.close, color: Color(0xFF8A9099)),
              size: inline ? 28 : 32,
              onPressed: () => NowWatching.notifier.value = null,
            ),
          ]),
        ),
      );
    });
  }

  Widget _artPlaceholder(double size) => Container(
        width: size, height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFF8800), Color(0xFFFF5A00)]),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.live_tv, size: 20, color: Colors.white),
      );
}

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
                colors: [Color(0xFFFF8800), Color(0xFFFF5A00)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: [
            const Icon(Icons.live_tv, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            const Text('虎牙直播 · 液态玻璃',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('看直播 · 弹幕 · 订阅 · 真实发送',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
            const SizedBox(height: 18),
            GlassButton(
              icon: const Icon(Icons.play_arrow),
              label: '进入直播间',
              onTap: () => _openEnterRoom(context),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _card(icon: Icons.subscriptions_outlined, color: kAccent,
            label: '我的订阅', sub: '点击查看已收藏的主播', onTap: onOpenFollows),
        const SizedBox(height: 12),
        _card(icon: Icons.account_circle, color: const Color(0xFFFFB25E),
            label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
            sub: '登录后可发真实弹幕 / 看真实订阅数', onTap: () => Get.toNamed('/huya_login')),
      ],
    );
  }

  Widget _card({required IconData icon, required Color color, required String label,
      required String sub, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kLine),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: kSub, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFC4C9CF)),
        ]),
      ),
    );
  }

  void _openEnterRoom(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('进入直播间', style: TextStyle(color: kText, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: kText),
          decoration: const InputDecoration(
              hintText: '输入房间号，如 31343932',
              hintStyle: TextStyle(color: Color(0xFFA6ADB5))),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(
            onPressed: () { Get.back(); goLive(ctrl.text.trim()); },
            child: const Text('进入', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
  }
}
