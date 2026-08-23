import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';

import '../live_play/background_play.dart';
import 'huya_login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          icon: Icons.account_circle,
          color: const Color(0xFF00D2FF),
          label: HuyaLoginManager().isLoggedIn ? '已登录虎牙账号' : '登录虎牙账号',
          sub: '粘贴 Cookie 登录，解锁真实弹幕与订阅数',
          onTap: () => Get.to(() => const HuyaLoginPage()),
        ),
        const SizedBox(height: 12),
        // ★ 后台播放开关
        Container(
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
                  color: const Color(0xFF7C6BFF).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.headphones,
                    color: Color(0xFF7C6BFF), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('后台播放',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('退出 App 后继续听直播声音',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: BackgroundPlayStore.enabled,
                builder: (context, on, _) => Switch(
                  value: on,
                  activeColor: const Color(0xFF00D2FF),
                  onChanged: (v) => BackgroundPlayStore.set(v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
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

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _Card({
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
