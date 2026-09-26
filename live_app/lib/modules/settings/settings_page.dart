import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/app_settings.dart';
import 'package:live_app/core/user_profile.dart';
import '../home/about_page.dart';
import '../live_play/background_play.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // 账号
        GestureDetector(
          onTap: () => Get.toNamed('/huya_login'),
          child: _card(
            icon: Icons.account_circle, color: const Color(0xFF00D2FF),
            title: '虎牙账号',
            sub: Obx(() => UserProfile.to.logged.value
                ? '已登录：${UserProfile.to.nickname.value}'
                : '粘贴 Cookie 登录，解锁真实弹幕与订阅数'),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),
        ),
        const SizedBox(height: 12),
        // 后台播放
        _card(
          icon: Icons.headphones, color: const Color(0xFFB46BFF),
          title: '后台播放',
          sub: const Text('退出 App 后继续听直播声音', style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: ValueListenableBuilder<bool>(
            valueListenable: BackgroundPlayStore.enabled,
            builder: (context, on, _) => Switch(
              value: on,
              activeColor: const Color(0xFFFF8800),
              onChanged: (v) {
                BackgroundPlayStore.set(v);
                if (v) BackgroundPlayStore.startService();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 深色模式
        _card(
          icon: Icons.dark_mode, color: const Color(0xFFFF8800),
          title: '深色模式',
          sub: const Text('切换明暗主题', style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Obx(() => Switch(
                value: AppSettings.to.isDark,
                activeColor: const Color(0xFFFF8800),
                onChanged: (_) => AppSettings.to.toggleTheme(),
              )),
        ),
        const SizedBox(height: 12),
        // 调试模式
        _card(
          icon: Icons.bug_report_outlined, color: const Color(0xFF7ED97E),
          title: '调试模式',
          sub: const Text('显示协议调试日志与调试页', style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Obx(() => Switch(
                value: AppSettings.to.debugEnabled.value,
                activeColor: const Color(0xFFFF8800),
                onChanged: AppSettings.to.setDebug,
              )),
        ),
        const SizedBox(height: 12),
        // 关于
        GestureDetector(
          onTap: () => Get.to(() => const AboutPage()),
          child: _card(
            icon: Icons.info_outline, color: const Color(0xFF4CB7FF),
            title: '关于',
            sub: const Text('HuyaLive · 液态玻璃版 · 参考 pure_live / dtv', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),
        ),
      ],
    );
  }

  Widget _card({required IconData icon, required Color color, required String title, required Widget sub, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          DefaultTextStyle(style: const TextStyle(color: Colors.white54, fontSize: 12), child: sub),
        ])),
        trailing,
      ]),
    );
  }
}
