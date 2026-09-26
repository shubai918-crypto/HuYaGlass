import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../../core/user_profile.dart';
import '../settings/settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 16),
        _buildMenuGroup([
          _MenuItemData(Icons.history_outlined, '观看历史', const Color(0xFF4CB7FF)),
          _MenuItemData(Icons.favorite_border, '我的收藏', const Color(0xFFFF6B9C)),
        ]),
        const SizedBox(height: 16),
        _buildMenuGroup([
          _MenuItemData(Icons.shield_outlined, '账号与安全', const Color(0xFF7ED97E)),
          _MenuItemData(Icons.notifications_outlined, '消息通知', const Color(0xFFFFB25E)),
        ]),
        const SizedBox(height: 16),
        _buildMenuGroup([
          _MenuItemData(Icons.settings_outlined, '设置', const Color(0xFFA0A0A0),
              onTap: () => Get.to(() => const SettingsPage())),
          _MenuItemData(Icons.info_outline, '关于 HuyaLive', const Color(0xFF00D2FF)),
        ]),
        Obx(() => UserProfile.to.logged.value
            ? Padding(padding: const EdgeInsets.only(top: 24), child: _buildLogoutButton())
            : const SizedBox.shrink()),
      ],
    );
  }

  // ---------- 顶部信息卡片（真实头像/昵称/UID/等级/签名） ----------
  Widget _buildHeaderCard() {
    return Obx(() {
      final p = UserProfile.to;
      final isLogin = p.logged.value;
      final avatarUrl = p.avatar.value;
      final nickname = isLogin
          ? (p.nickname.value.isNotEmpty ? p.nickname.value : '虎牙用户')
          : '点击登录';
      final uidText = isLogin
          ? (p.uid.value.isNotEmpty ? 'UID: ${p.uid.value}' : 'UID: 已登录')
          : '登录解锁更多功能与真实弹幕';
      final level = p.level.value;
      final sign = p.signature.value;

      return GestureDetector(
        onTap: isLogin ? null : () => Get.toNamed('/huya_login'),
        child: GlassContainer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 28),
          padding: const EdgeInsets.all(20),
          useOwnLayer: true,
          quality: GlassQuality.premium,
          settings: LiquidGlassSettings(
            blur: 20,
            thickness: 30,
            glassColor: Colors.black.withOpacity(0.25),
            bodyMode: GlassBodyMode.adaptive,
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white10,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 32, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          nickname,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLogin && level.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8800).withOpacity(0.18),
                            border: Border.all(color: const Color(0xFFFF8800).withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(level,
                              style: const TextStyle(
                                  color: Color(0xFFFF8800),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(uidText,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    if (isLogin && sign.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sign,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 24),
            ],
          ),
        ),
      );
    });
  }

  // ---------- 菜单分组 ----------
  Widget _buildMenuGroup(List<_MenuItemData> items) {
    return GlassContainer(
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      useOwnLayer: true,
      settings: LiquidGlassSettings(
          blur: 15, thickness: 25, glassColor: Colors.black.withOpacity(0.20)),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _buildMenuItem(items[i]),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 60, right: 16),
                child: Divider(height: 1, color: Colors.white.withOpacity(0.08)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItemData item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(item.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  // ---------- 退出登录 ----------
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        final ok = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('退出登录', style: TextStyle(color: Colors.white)),
            content: const Text('确定要退出当前虎牙账号吗？', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('取消', style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text('退出', style: TextStyle(color: Color(0xFFE5484D)))),
            ],
          ),
        );
        if (ok == true) {
          try {
            HuyaLoginManager().logout();
          } catch (_) {}
          await UserProfile.to.clear();
          Get.snackbar('提示', '已退出登录', snackPosition: SnackPosition.BOTTOM);
        }
      },
      child: GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 999),
        padding: const EdgeInsets.symmetric(vertical: 14),
        settings: LiquidGlassSettings(
            blur: 10, thickness: 20, glassColor: const Color(0x22E5484D)),
        child: const Center(
          child: Text('退出登录',
              style: TextStyle(
                  color: Color(0xFFE5484D), fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;
  _MenuItemData(this.icon, this.title, this.color, {this.onTap});
}
