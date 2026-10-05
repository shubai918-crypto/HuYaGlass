import 'dart:convert';
import 'dart:io';

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

class _RecItem {
  final String roomId;
  final String nick;
  final String avatar;
  final String title;
  final String screenshot;
  final String game;
  final int viewers;
  final double aspect;
  _RecItem({
    required this.roomId,
    required this.nick,
    required this.avatar,
    required this.title,
    required this.screenshot,
    required this.game,
    required this.viewers,
    required this.aspect,
  });
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

  // ★ Apple Music Demo 同款玻璃 + 酷安悬浮投影
  LiquidGlassSettings _barGlass() => LiquidGlassSettings(
        glassColor: const Color(0xAAF2F2F7),
        thickness: 30,
        blur: 2,
        chromaticAberration: 0.01,
        lightAngle: GlassDefaults.lightAngle,
        lightIntensity: 0.2,
        ambientStrength: 0,
        refractiveIndex: 1.2,
        fresnelStrength: 0.0,
        saturation: 1.2,
        specularSharpness: GlassSpecularSharpness.medium,
        shadowElevation: 2.0,
      );

  LiquidGlassSettings _visibleGlass() => LiquidGlassSettings(
        glassColor: const Color(0x99F2F2F7),
        thickness: 24,
        blur: 4,
        chromaticAberration: 0.01,
        lightIntensity: 0.3,
        refractiveIndex: 1.15,
        saturation: 1.2,
        specularSharpness: GlassSpecularSharpness.medium,
        shadowElevation: 1.5,
      );

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
                settings: _visibleGlass(),
                child: const Text('HuyaLive',
                    style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              actions: [
                GlassIconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFF1F2329)),
                  size: 44,
                  settings: _visibleGlass(),
                  glowColor: kAccent.withOpacity(0.35),
                  onPressed: () => _showQuickSettings(context),
                ),
              ],
            ),
            body: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                bottom: 0,
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
            // ★ 回退 GlassTabBar.minimizable：整条液态胶囊 + 指示器果冻 + 收拢动画
            bottomBar: GlassTabBar.minimizable(
              minimized: _isMinimized,
              onMinimizedTabTap: () => setState(() => _isMinimized = false),
              bottomAccessory: room != null ? _buildMiniBar(room) : null,
              bottomAccessoryHeight: room != null ? 50 : null,
              bottomAccessorySpacing: 8,
              settings: _barGlass(),
              barHeight: 64,
              minimizedBarHeight: 52,
              horizontalPadding: 16,
              verticalPadding: 12,
              spacing: 8,
              selectedIndex: _selectedIndex,
              onTabSelected: _select,
              indicatorColor: kAccent.withOpacity(0.14),
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
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFD8DBE0), borderRadius: BorderRadius.circular(2))),
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
      final avatarSize = inline ? 30.0 : 38.0;
      return GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 999),
        padding: EdgeInsets.symmetric(horizontal: inline ? 10 : 12, vertical: 4),
        useOwnLayer: true,
        quality: GlassQuality.premium,
        settings: _barGlass(),
        child: SizedBox(
          height: 42,
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
                    const Text('正在播放 · 虎牙直播', maxLines: 1, style: TextStyle(color: kSub, fontSize: 10)),
                ],
              ),
            ),
            GlassIconButton(
              icon: const Icon(Icons.play_arrow, color: kAccent),
              size: inline ? 30 : 34,
              onPressed: () => goLive(room.roomId, nickname: room.nickname, avatarUrl: room.avatarUrl),
            ),
            const SizedBox(width: 4),
            GlassIconButton(
              icon: const Icon(Icons.close, color: Color(0xFF8A9099)),
              size: inline ? 26 : 30,
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

// ─────────────────────────────────────────────────────────────────────────────
// 首页：banner + 快捷入口 + 直播推荐瀑布流
// ─────────────────────────────────────────────────────────────────────────────
class _HomeView extends StatefulWidget {
  final VoidCallback onOpenFollows;
  const _HomeView({required this.onOpenFollows});
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final List<_RecItem> _left = [];
  final List<_RecItem> _right = [];
  final Set<String> _followed = {};
  double _hLeft = 0;
  double _hRight = 0;
  int _page = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _end = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  String _fmtView(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  // ★ 修复：数字房间号 lProfileId 优先（与搜索页同源），别名 privateHost 兜底
  Future<List<_RecItem>> _fetchRecPage(int page) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client
          .getUrl(Uri.parse('https://www.huya.com/cache.php?m=LiveList&do=getLiveListByPage&tagAll=0&page=$page'))
          .timeout(const Duration(seconds: 7));
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
      req.headers.set('Referer', 'https://www.huya.com/');
      final resp = await req.close().timeout(const Duration(seconds: 7));
      final body = await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
      final dyn = jsonDecode(body);
      final datas = (dyn['data']?['datas'] as List?) ?? const [];
      const aspects = [0.75, 1.0, 1.33, 0.85];
      final out = <_RecItem>[];
      for (final d in datas) {
        final m = d as Map<String, dynamic>;
        String pickStr(List<String> keys) {
          for (final k in keys) {
            final v = m[k];
            if (v != null && '$v'.isNotEmpty) return '$v';
          }
          return '';
        }

        // ★ 数字房间号优先：lProfileId → lPid → uid → privateHost 别名兜底
        final lpid = m['lProfileId'] ?? m['lPid'] ?? m['iProfileId'] ?? m['lRoomId'];
        final lpidNum = int.tryParse('$lpid');
        final host = pickStr(['privateHost', 'sPrivateHost']);
        final uid = pickStr(['uid', 'lUid', 'sUid']);
        final roomId = (lpidNum != null && lpidNum > 0)
            ? '$lpidNum'
            : (uid.isNotEmpty && int.tryParse(uid) != null
                ? uid
                : (host.isNotEmpty ? host : uid));
        if (roomId.isEmpty) continue;
        final nick = pickStr(['nickName', 'sNick', 'sNickname', 'nick']);
        final intro = pickStr(['introduction', 'sIntroduction']);
        final tc = m['totalCount'] ?? m['lTotalCount'] ?? m['sTotalCount'] ?? m['lOnlineTotal'];
        final viewers = tc is int ? tc : (int.tryParse('$tc') ?? 0);
        out.add(_RecItem(
          roomId: roomId,
          nick: nick,
          avatar: pickStr(['avatar180', 'sAvatar180', 'avatar']),
          title: intro.isNotEmpty ? intro : (nick.isNotEmpty ? '$nick 的直播间' : '直播间'),
          screenshot: pickStr(['screenshot', 'sScreenshot']),
          game: pickStr(['gameFullName', 'sGameFullName']),
          viewers: viewers,
          aspect: aspects[(roomId.hashCode & 0x7fffffff) % aspects.length],
        ));
      }
      return out;
    } finally {
      client.close(force: true);
    }
  }

  void _append(List<_RecItem> items) {
    final colW = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    for (final it in items) {
      final h = colW / it.aspect + 108;
      if (_hLeft <= _hRight) {
        _left.add(it);
        _hLeft += h + 10;
      } else {
        _right.add(it);
        _hRight += h + 10;
      }
    }
  }

  Future<void> _seedFollows(List<_RecItem> items) async {
    for (final it in items) {
      if (_followed.contains(it.roomId)) continue;
      try {
        if (await FollowStore.contains(it.roomId)) _followed.add(it.roomId);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadFirst() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = false;
      _end = false;
      _page = 0;
      _left.clear();
      _right.clear();
      _hLeft = 0;
      _hRight = 0;
    });
    try {
      final items = await _fetchRecPage(1);
      if (!mounted) return;
      _page = 1;
      _append(items);
      setState(() => _loading = false);
      _seedFollows(items);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _end || _page == 0) return;
    setState(() => _loadingMore = true);
    try {
      final items = await _fetchRecPage(_page + 1);
      if (!mounted) return;
      if (items.isEmpty) {
        _end = true;
      } else {
        _page++;
        _append(items);
        _seedFollows(items);
      }
      setState(() => _loadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow(_RecItem it) async {
    final has = _followed.contains(it.roomId);
    if (has) {
      await FollowStore.remove(it.roomId);
      _followed.remove(it.roomId);
      Get.snackbar('已取消订阅', it.nick, snackPosition: SnackPosition.BOTTOM);
    } else {
      await FollowStore.add(FollowItem(roomId: it.roomId, name: it.nick, avatar: it.avatar));
      _followed.add(it.roomId);
      Get.snackbar('已订阅', it.nick, snackPosition: SnackPosition.BOTTOM);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification && n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        color: kAccent,
        onRefresh: _loadFirst,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          children: [
            _banner(),
            const SizedBox(height: 12),
            _quickRow(),
            const SizedBox(height: 20),
            _feedHeader(),
            const SizedBox(height: 10),
            _masonry(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF8800), Color(0xFFFF5A00)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Icon(Icons.live_tv, size: 30, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('虎牙直播 · 液态玻璃',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('看直播 · 弹幕 · 订阅 · 真实发送',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
        ])),
        GlassButton.custom(
          onTap: () => _openEnterRoom(context),
          height: 38,
          shape: const LiquidRoundedRectangle(borderRadius: 19),
          useOwnLayer: true,
          quality: GlassQuality.premium,
          stretch: 0.5,
          anchorStretchSettings: const AnchorStretchSettings(
              intensity: 0.6, squashFactor: 0.15, translationDamping: 0.12, bounciness: 0.15),
          settings: LiquidGlassSettings(
            glassColor: Colors.white.withOpacity(0.22),
            bodyMode: GlassBodyMode.clear,
            thickness: 24,
            blur: 2,
            lightIntensity: 0.6,
            chromaticAberration: 0.01,
            saturation: 1.2,
            specularSharpness: GlassSpecularSharpness.medium,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('进直播间', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _quickRow() {
    return Row(children: [
      Expanded(child: _quickCard(Icons.subscriptions_outlined, kAccent, '我的订阅', widget.onOpenFollows)),
      const SizedBox(width: 10),
      Expanded(child: _quickCard(Icons.account_circle, const Color(0xFFFFB25E),
          HuyaLoginManager().isLoggedIn ? '已登录' : '登录', () => Get.toNamed('/huya_login'))),
    ]);
  }

  Widget _quickCard(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, color: Color(0xFFC4C9CF), size: 16),
        ]),
      ),
    );
  }

  Widget _feedHeader() {
    return Row(children: [
      const Icon(Icons.whatshot, color: kAccent, size: 18),
      const SizedBox(width: 6),
      Text('直播推荐 (${_left.length + _right.length})',
          style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w800)),
      const Spacer(),
      GlassIconButton(
        icon: const Icon(Icons.refresh, color: kAccent),
        size: 38,
        settings: LiquidGlassSettings(
            glassColor: const Color(0x99F2F2F7), thickness: 20, blur: 4,
            lightIntensity: 0.3, specularSharpness: GlassSpecularSharpness.medium, shadowElevation: 1.0),
        onPressed: _loadFirst,
      ),
    ]);
  }

  Widget _masonry() {
    if (_loading && _left.isEmpty && _right.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5)),
      );
    }
    if (_error && _left.isEmpty) {
      return GestureDetector(
        onTap: _loadFirst,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
          child: const Column(children: [
            Icon(Icons.wifi_off_outlined, color: Color(0xFFC4C9CF), size: 36),
            SizedBox(height: 8),
            Text('加载失败，点击重试', style: TextStyle(color: kSub, fontSize: 13)),
          ]),
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(children: _left.map(_recCard).toList())),
      const SizedBox(width: 10),
      Expanded(child: Column(children: _right.map(_recCard).toList())),
    ]);
  }

  Widget _recCard(_RecItem it) {
    final followed = _followed.contains(it.roomId);
    return GestureDetector(
      onTap: () => goLive(it.roomId, nickname: it.nick, avatarUrl: it.avatar),
      onLongPress: () => _toggleFollow(it),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Stack(children: [
              AspectRatio(
                aspectRatio: it.aspect,
                child: it.screenshot.isNotEmpty
                    ? Image.network(it.screenshot, fit: BoxFit.cover, gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => _coverPh())
                    : _coverPh(),
              ),
              Positioned(
                left: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                  child: const Text('直播中', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                right: 8, bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.remove_red_eye, size: 10, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(_fmtView(it.viewers), style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 8),
              Row(children: [
                CircleAvatar(radius: 9, backgroundColor: const Color(0xFFF2F3F5),
                    backgroundImage: it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
                    child: it.avatar.isEmpty ? const Icon(Icons.person, size: 10, color: Color(0xFFA6ADB5)) : null),
                const SizedBox(width: 6),
                Expanded(child: Text(it.game.isNotEmpty ? '${it.nick} · ${it.game}' : it.nick,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kSub, fontSize: 10))),
                Icon(followed ? Icons.favorite : Icons.favorite_border,
                    size: 15, color: followed ? const Color(0xFFE5484D) : const Color(0xFFC4C9CF)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _coverPh() => Container(
        color: const Color(0xFFF2F3F5),
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv, color: Color(0xFFC4C9CF), size: 28),
      );

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))),
      );
    }
    if (_end) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('— 到底啦 —', style: TextStyle(color: Color(0xFFA6ADB5), fontSize: 11))),
      );
    }
    return const SizedBox(height: 8);
  }

  void _openEnterRoom(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
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
