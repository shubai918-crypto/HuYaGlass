import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/app_settings.dart';
import 'package:live_app/core/huya_glass_theme.dart';
import 'package:live_app/core/notify_manager.dart';
import 'package:live_app/core/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/about_page.dart';
import '../live_play/background_play.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlassLargeTitleController _titleController = GlassLargeTitleController();
  bool _noticeOn = false;

  @override
  void initState() {
    super.initState();
    LiveNotifyManager.to.isEnabled().then((v) {
      if (mounted) setState(() => _noticeOn = v);
    });
    // 读取本地 iOS 27 开关状态
    SharedPreferences.getInstance().then((p) {
      if (mounted) kHuyaUseIos27.value = p.getBool('glass_ios27') ?? true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _toggleIos27(bool v) async {
    kHuyaUseIos27.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('glass_ios27', v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final topPad = mediaQuery.padding.top;
    final botPad = mediaQuery.padding.bottom;

    // ★ 使用 HuyaGlassScope 包裹，使 iOS 27 开关全局生效
    return HuyaGlassScope(
      child: GlassScaffold(
        background: ColoredBox(color: kHuyaBg),
        appBar: GlassAppBar.pinned(
          buttonSettings: kHuyaGlass(context),
          title: Text('设置', style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontWeight: FontWeight.w600, fontSize: 17)),
          largeTitleController: _titleController,
        ),
        body: CustomScrollView(
          controller: _titleController.scrollController,
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPad + 44)),
            
            // ★ 大标题 (滚动时自动缩小到 AppBar)
            GlassLargeTitle(
              text: '设置',
              controller: _titleController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            ),

            // ── 1. 账号 Hero 卡片 (悬浮感，使用 GlassContainer) ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: () => Get.toNamed('/huya_login'),
                  child: GlassContainer(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 24),
                    padding: const EdgeInsets.all(16),
                    useOwnLayer: true,
                    quality: GlassQuality.premium,
                    settings: kHuyaGlass(context),
                    child: Obx(() => Row(children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2), width: 2)),
                        child: CircleAvatar(
                          radius: 28, backgroundColor: Colors.white10,
                          backgroundImage: UserProfile.to.avatar.value.isNotEmpty ? NetworkImage(UserProfile.to.avatar.value) : null,
                          child: UserProfile.to.avatar.value.isEmpty ? const Icon(CupertinoIcons.person_fill, size: 28, color: Colors.white54) : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(UserProfile.to.logged.value ? (UserProfile.to.nickname.value.isNotEmpty ? UserProfile.to.nickname.value : '虎牙用户') : '虎牙账号',
                            style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(UserProfile.to.logged.value ? 'UID: ${UserProfile.to.uid.value}' : '粘贴 Cookie 登录，解锁真实弹幕',
                            style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 13)),
                      ])),
                      Icon(CupertinoIcons.chevron_right, color: CupertinoColors.tertiaryLabel.resolveFrom(context), size: 16),
                    ])),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 2. 外观与材质 (Inset Grouped 实色卡片，遵循 Rule 1 & 2) ────────
            _buildSectionHeader('外观与材质'),
            SliverToBoxAdapter(child: _buildCard([
              _buildSwitchRow(
                icon: CupertinoIcons.sparkles, color: kHuyaCyan, title: 'iOS 27 液态材质',
                sub: '霜感 frost · 新 rim 光学',
                value: kHuyaUseIos27.value,
                onChanged: _toggleIos27,
              ),
              _buildDivider(),
              Obx(() => _buildSwitchRow(
                icon: CupertinoIcons.moon_stars_fill, color: kHuyaOrange, title: '深色模式',
                sub: '切换明暗主题',
                value: AppSettings.to.isDark,
                onChanged: (_) => AppSettings.to.toggleTheme(),
              )),
            ])),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── 3. 播放与通知 ───────────────────────────────────────────────
            _buildSectionHeader('播放与通知'),
            SliverToBoxAdapter(child: _buildCard([
              ValueListenableBuilder<bool>(
                valueListenable: BackgroundPlayStore.enabled,
                builder: (context, on, _) => _buildSwitchRow(
                  icon: CupertinoIcons.headphones, color: const Color(0xFFB46BFF), title: '后台播放',
                  sub: '退出 App 后继续听直播声音',
                  value: on,
                  onChanged: (v) {
                    BackgroundPlayStore.set(v);
                    if (v) BackgroundPlayStore.startService();
                  },
                ),
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: CupertinoIcons.bell_fill, color: kHuyaOrange, title: '开播提醒',
                sub: '订阅主播开播时发系统通知',
                value: _noticeOn,
                onChanged: (v) {
                  setState(() => _noticeOn = v);
                  LiveNotifyManager.to.setEnabled(v);
                },
              ),
            ])),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── 4. 系统 ───────────────────────────────────────────────────
            _buildSectionHeader('系统'),
            SliverToBoxAdapter(child: _buildCard([
              Obx(() => _buildSwitchRow(
                icon: CupertinoIcons.ant_fill, color: const Color(0xFF7ED97E), title: '调试模式',
                sub: '显示协议调试日志',
                value: AppSettings.to.debugEnabled.value,
                onChanged: AppSettings.to.setDebug,
              )),
              _buildDivider(),
              _buildNavRow(
                icon: CupertinoIcons.info_circle_fill, color: kHuyaCyan, title: '关于 HuyaLive',
                sub: '开发者：白薯 + qwen3.8Max',
                onTap: () => Get.to(() => const AboutPage()),
              ),
            ])),

            SliverToBoxAdapter(child: SizedBox(height: 40 + botPad)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI BUILDERS (Inset Grouped Style)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 16, 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.secondaryLabel.resolveFrom(context), letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kHuyaCardBg.resolveFrom(context), // ★ 实色背景，保证滚动性能
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Container(height: 0.5, color: kHuyaDivider.resolveFrom(context), margin: const EdgeInsets.only(left: 54));
  }

  Widget _buildSwitchRow({
    required IconData icon, required Color color, required String title, required String sub,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 12)),
        ])),
        // ★ 使用官方 GlassSwitch，自动适配 iOS 26/27 质感
        GlassSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: kHuyaOrange,
          useOwnLayer: true,
          quality: GlassQuality.premium,
        ),
      ]),
    );
  }

  Widget _buildNavRow({
    required IconData icon, required Color color, required String title, required String sub, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 12)),
          ])),
          Icon(CupertinoIcons.chevron_right, color: CupertinoColors.tertiaryLabel.resolveFrom(context), size: 16),
        ]),
      ),
    );
  }
}
