import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/app_settings.dart';
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
  bool _ios27 = true;
  bool _noticeOn = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _ios27 = p.getBool('glass_ios27') ?? true);
    });
    LiveNotifyManager.to.isEnabled().then((v) {
      if (mounted) setState(() => _noticeOn = v);
    });
  }

  Future<void> _setIos27(bool v) async {
    setState(() => _ios27 = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('glass_ios27', v);
  }

  /// ★ iOS 27 霜感材质 / iOS 26 标准材质 一键切换
  LiquidGlassSettings get _cardGlass => _ios27
      ? LiquidGlassSettings.ios27Dark // 1.8.0 预设：frost + 新 rim 光学项
      : const LiquidGlassSettings(
          blur: 18,
          thickness: 26,
          saturation: 1.2,
          refractiveIndex: 1.15,
          glassColor: Color(0x3314141C),
        );

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      contentAwareBrightness: true,
      statusBarStyle: GlassStatusBarStyle.light,
      background: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.8),
              radius: 1.6,
              colors: [Color(0xFF2D1B4E), Color(0xFF12121A), Color(0xFF050508)],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ),
      appBar: GlassAppBar(
        title: const Text('设置',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ★ 账号大卡：premium + iOS27 霜感
          GestureDetector(
            onTap: () => Get.toNamed('/huya_login'),
            child: GlassContainer(
              shape: const LiquidRoundedSuperellipse(borderRadius: 28),
              padding: const EdgeInsets.all(18),
              useOwnLayer: true,
              quality: GlassQuality.premium,
              settings: _cardGlass,
              child: Obx(() => Row(children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white10,
                        backgroundImage: UserProfile.to.avatar.value.isNotEmpty
                            ? NetworkImage(UserProfile.to.avatar.value)
                            : null,
                        child: UserProfile.to.avatar.value.isEmpty
                            ? const Icon(CupertinoIcons.person_fill, size: 26, color: Colors.white54)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          UserProfile.to.logged.value
                              ? (UserProfile.to.nickname.value.isNotEmpty
                                  ? UserProfile.to.nickname.value
                                  : '虎牙用户')
                              : '虎牙账号',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          UserProfile.to.logged.value
                              ? 'UID: ${UserProfile.to.uid.value}'
                              : '粘贴 Cookie 登录，解锁真实弹幕与订阅数',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                        ),
                      ]),
                    ),
                    const Icon(CupertinoIcons.chevron_right, color: Colors.white30, size: 18),
                  ])),
            ),
          ),
          const SizedBox(height: 14),

          // ★ 外观组：iOS27 材质 + 深色模式
          _group([
            _switchTile(
              icon: CupertinoIcons.sparkles, color: const Color(0xFF00D2FF),
              title: 'iOS 27 液态材质', sub: '霜感 frost · 新 rim 光学（premium 画质）',
              value: _ios27, onChanged: _setIos27,
            ),
            _divider(),
            Obx(() => _switchTile(
                  icon: CupertinoIcons.moon_stars_fill, color: const Color(0xFFFF8800),
                  title: '深色模式', sub: '切换明暗主题',
                  value: AppSettings.to.isDark, onChanged: (_) => AppSettings.to.toggleTheme(),
                )),
          ]),
          const SizedBox(height: 14),

          // ★ 播放与通知组
          _group([
            ValueListenableBuilder<bool>(
              valueListenable: BackgroundPlayStore.enabled,
              builder: (context, on, _) => _switchTile(
                icon: CupertinoIcons.headphones, color: const Color(0xFFB46BFF),
                title: '后台播放', sub: '退出 App 后继续听直播声音',
                value: on,
                onChanged: (v) {
                  BackgroundPlayStore.set(v);
                  if (v) BackgroundPlayStore.startService();
                },
              ),
            ),
            _divider(),
            _switchTile(
              icon: CupertinoIcons.bell_fill, color: const Color(0xFFFFB25E),
              title: '开播提醒', sub: '订阅主播开播时发系统通知',
              value: _noticeOn,
              onChanged: (v) {
                setState(() => _noticeOn = v);
                LiveNotifyManager.to.setEnabled(v);
              },
            ),
          ]),
          const SizedBox(height: 14),

          // ★ 系统组：调试 + 关于
          _group([
            Obx(() => _switchTile(
                  icon: CupertinoIcons.ant_fill, color: const Color(0xFF7ED97E),
                  title: '调试模式', sub: '显示协议调试日志与调试页',
                  value: AppSettings.to.debugEnabled.value, onChanged: AppSettings.to.setDebug,
                )),
            _divider(),
            GestureDetector(
              onTap: () => Get.to(() => const AboutPage()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF4CB7FF).withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF4CB7FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('关于', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('HuyaLive · 液态玻璃版 · 参考 pure_live / dtv',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  ),
                  const Icon(CupertinoIcons.chevron_right, color: Colors.white30, size: 18),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ★ 玻璃分组容器（跟随 iOS27 开关切换材质）
  Widget _group(List<Widget> rows) {
    return GlassContainer(
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      useOwnLayer: true,
      quality: GlassQuality.premium,
      settings: _cardGlass,
      child: Column(children: rows),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.only(left: 70, right: 16),
        child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
      );

  // ★ GlassSwitch 行
  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
          ]),
        ),
        GlassSwitch(
          value: value,
          onChanged: onChanged,
          quality: GlassQuality.premium,
          activeColor: const Color(0xFFFF8800),
        ),
      ]),
    );
  }
}
