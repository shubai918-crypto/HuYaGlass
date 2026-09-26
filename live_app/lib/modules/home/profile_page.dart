import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../settings/settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ★ 顶部个人信息大卡片 (液态玻璃)
        _buildHeaderCard(),
        
        const SizedBox(height: 16),

        // ★ 第一组菜单：常用功能
        _buildMenuGroup([
          _MenuItemData(Icons.history_outlined, '观看历史', const Color(0xFF4CB7FF)),
          _MenuItemData(Icons.favorite_border, '我的收藏', const Color(0xFFFF6B9C)),
          _MenuItemData(Icons.subscriptions_outlined, '我的订阅', const Color(0xFFFF8800), onTap: () {
            // 快捷跳转到订阅页 (首页的第3个Tab)
            DefaultTabController.of(context)?.animateTo(2); 
          }),
        ]),

        const SizedBox(height: 16),

        // ★ 第二组菜单：账号与系统
        _buildMenuGroup([
          _MenuItemData(Icons.shield_outlined, '账号与安全', const Color(0xFF7ED97E)),
          _MenuItemData(Icons.notifications_outlined, '消息通知', const Color(0xFFFFB25E)),
        ]),

        const SizedBox(height: 16),

        // ★ 第三组菜单：设置与关于
        _buildMenuGroup([
          _MenuItemData(Icons.settings_outlined, '设置', const Color(0xFFA0A0A0), onTap: () {
            Get.to(() => const SettingsPage());
          }),
          _MenuItemData(Icons.info_outline, '关于 HuyaLive', const Color(0xFF00D2FF)),
        ]),

        // ★ 退出登录按钮 (仅登录态显示)
        Obx(() => HuyaLoginManager().isLoggedIn 
            ? Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _buildLogoutButton(),
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ---------- 顶部信息卡片 ----------
  Widget _buildHeaderCard() {
    return Obx(() {
      final loginMgr = HuyaLoginManager();
      final isLogin = loginMgr.isLoggedIn;
      
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
              // 头像
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white10,
                  backgroundImage: (isLogin && loginMgr.avatar.isNotEmpty) 
                      ? NetworkImage(loginMgr.avatar) 
                      : null,
                  child: (!isLogin || loginMgr.avatar.isEmpty) 
                      ? const Icon(Icons.person, size: 32, color: Colors.white54) 
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              
              // 昵称与 UID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLogin ? (loginMgr.nickname.isNotEmpty ? loginMgr.nickname : '虎牙用户') : '点击登录',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLogin ? 'UID: ${loginMgr.uid}' : '登录解锁更多功能与真实弹幕',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // 粉丝数 / 箭头
              if (isLogin)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('粉丝', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '--', // 虎牙网页端个人粉丝数抓取较复杂，此处预留 UI 占位
                      style: TextStyle(
                        color: const Color(0xFFFF8800),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white38, size: 28),
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
        blur: 15,
        thickness: 25,
        glassColor: Colors.black.withOpacity(0.20),
      ),
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
              child: Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
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
              TextButton(onPressed: () => Get.back(result: false), child: const Text('取消', style: TextStyle(color: Colors.white54))),
              TextButton(onPressed: () => Get.back(result: true), child: const Text('退出', style: TextStyle(color: Color(0xFFE5484D)))),
            ],
          ),
        );
        if (ok == true) {
          HuyaLoginManager().logout();
          Get.snackbar('提示', '已退出登录', snackPosition: SnackPosition.BOTTOM);
        }
      },
      child: GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 999),
        padding: const EdgeInsets.symmetric(vertical: 14),
        settings: LiquidGlassSettings(blur: 10, thickness: 20, glassColor: const Color(0x22E5484D)),
        child: const Center(
          child: Text('退出登录', style: TextStyle(color: Color(0xFFE5484D), fontSize: 15, fontWeight: FontWeight.w600)),
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
