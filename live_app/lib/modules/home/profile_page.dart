import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:live_app/core/user_profile.dart';

import '../settings/settings_page.dart';
import 'about_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'notice_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  static ValueChanged<int>? onJumpTab;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UserProfile.to.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const SizedBox(height: 8),
            _accountCard(),
            const SizedBox(height: 24),
            _section('我的服务'),
            const SizedBox(height: 8),
            _group([
              _row(Icons.history_outlined, const Color(0xFF4CB7FF), '观看历史', '最近进入的直播间',
                  () => Get.to(() => const HistoryPage())),
              _divider(),
              _row(Icons.subscriptions_outlined, kAccent, '我的订阅', '查看已关注的主播',
                  () => ProfilePage.onJumpTab?.call(2)),
            ]),
            const SizedBox(height: 24),
            _section('消息与系统'),
            const SizedBox(height: 8),
            _group([
              _row(Icons.notifications_outlined, const Color(0xFFFFB25E), '消息通知', '开播提醒开关',
                  () => Get.to(() => const NoticePage())),
              _divider(),
              _row(Icons.settings_outlined, const Color(0xFF8A9099), '设置', '主题 / 播放 / 调试',
                  () => Get.to(() => const SettingsPage())),
              _divider(),
              _row(Icons.info_outline, const Color(0xFF4CB7FF), '关于 HuyaLive', '开发者：白薯 + qwen3.8Max',
                  () => Get.to(() => const AboutPage())),
            ]),
            const SizedBox(height: 28),
            Obx(() => UserProfile.to.logged.value
                ? GestureDetector(
                    onTap: () async {
                      final ok = await Get.dialog<bool>(AlertDialog(
                        backgroundColor: kCard,
                        title: const Text('退出登录', style: TextStyle(color: kText)),
                        content: const Text('确定要退出当前虎牙账号吗？', style: TextStyle(color: kSub)),
                        actions: [
                          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消', style: TextStyle(color: kSub))),
                          TextButton(onPressed: () => Get.back(result: true), child: const Text('退出', style: TextStyle(color: Color(0xFFE5484D)))),
                        ],
                      ));
                      if (ok == true) {
                        try { HuyaLoginManager().logout(); } catch (_) {}
                        await UserProfile.to.clear();
                        Get.snackbar('提示', '已退出登录', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                      child: const Center(child: Text('退出登录', style: TextStyle(color: Color(0xFFE5484D), fontSize: 15, fontWeight: FontWeight.w600))),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _accountCard() {
    return Obx(() {
      final logged = UserProfile.to.logged.value;
      final avatar = UserProfile.to.avatar.value;
      final nick = UserProfile.to.nickname.value;
      final uid = UserProfile.to.uid.value;
      final level = UserProfile.to.level.value;
      return GestureDetector(
        onTap: logged ? null : () => Get.toNamed('/huya_login'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
          child: Row(children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kAccent.withOpacity(0.5), width: 2)),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFF2F3F5),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.person, size: 30, color: Color(0xFFA6ADB5)) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(logged ? (nick.isNotEmpty ? nick : '虎牙用户') : '点击登录',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800))),
                if (logged && level.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: kAccent.withOpacity(0.12), border: Border.all(color: kAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
                    child: Text(level, style: const TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(logged ? (uid.isNotEmpty ? 'UID: $uid' : '已登录') : '粘贴 Cookie 登录，解锁真实弹幕',
                  style: const TextStyle(color: kSub, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right, color: Color(0xFFC4C9CF)),
          ]),
        ),
      );
    });
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
}
