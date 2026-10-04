import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/app_settings.dart';
import 'package:live_app/core/notify_manager.dart';
import 'package:live_app/core/user_profile.dart';

import '../home/about_page.dart';
import '../home/home_page.dart';
import '../live_play/background_play.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _noticeOn = false;

  @override
  void initState() {
    super.initState();
    LiveNotifyManager.to.isEnabled().then((v) {
      if (mounted) setState(() => _noticeOn = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kText),
        title: const Text('设置', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _section('账号'),
          const SizedBox(height: 8),
          _group([
            Obx(() => _row(
                  Icons.account_circle, const Color(0xFF4CB7FF),
                  UserProfile.to.logged.value ? '已登录：${UserProfile.to.nickname.value}' : '虎牙账号',
                  UserProfile.to.logged.value ? '点击进入账号管理' : '粘贴 Cookie 登录，解锁真实弹幕与订阅数',
                  () => Get.toNamed('/huya_login'),
                )),
          ]),
          const SizedBox(height: 24),
          _section('播放与通知'),
          const SizedBox(height: 8),
          _group([
            ValueListenableBuilder<bool>(
              valueListenable: BackgroundPlayStore.enabled,
              builder: (context, on, _) => _switchRow(
                Icons.headphones, const Color(0xFF9A4FE0), '后台播放', '退出 App 后继续听直播声音',
                value: on,
                onChanged: (v) {
                  BackgroundPlayStore.set(v);
                  if (v) BackgroundPlayStore.startService();
                },
              ),
            ),
            _divider(),
            _switchRow(
              Icons.notifications_outlined, const Color(0xFFFFB25E), '开播提醒', '订阅主播开播时发系统通知',
              value: _noticeOn,
              onChanged: (v) {
                setState(() => _noticeOn = v);
                LiveNotifyManager.to.setEnabled(v);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _section('开发者'),
          const SizedBox(height: 8),
          _group([
            Obx(() => _switchRow(
                  Icons.bug_report_outlined, const Color(0xFF3E9E4C), '调试模式', '显示协议调试日志与调试页',
                  value: AppSettings.to.debugEnabled.value,
                  onChanged: AppSettings.to.setDebug,
                )),
            _divider(),
            _row(Icons.info_outline, const Color(0xFF4CB7FF), '关于', 'HuyaLive · 液态玻璃版 · 参考 pure_live / dtv',
                () => Get.to(() => const AboutPage())),
          ]),
        ],
      ),
    );
  }

  Widget _section(String t) => Text(t, style: const TextStyle(color: kSub, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _group(List<Widget> children) => Container(
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Column(children: children),
      );

  Widget _divider() => Container(height: 0.5, color: kLine, margin: const EdgeInsets.only(left: 62));

  Widget _row(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kSub, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: Color(0xFFC4C9CF), size: 18),
        ]),
      ),
    );
  }

  Widget _switchRow(IconData icon, Color color, String title, String sub,
      {required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: kSub, fontSize: 12)),
        ])),
        Switch(value: value, activeColor: kAccent, onChanged: onChanged),
      ]),
    );
  }
}
