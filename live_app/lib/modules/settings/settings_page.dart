import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/liquid_glass.dart';
import '../login/huya_login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('设置', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Obx(() => LiquidGlass(
                    padding: const EdgeInsets.all(16),
                    child: InkWell(
                      onTap: () async {
                        await Get.to(() => const HuyaLoginPage());
                        // 返回后强制刷新 Obx
                        HuyaLoginManager().instanceVersion.value++;
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle,
                              color: Color(0xFF00D2FF), size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('虎牙账号',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  HuyaLoginManager().isLoggedIn
                                      ? '已登录 · 可发真实弹幕 / 看真实订阅数'
                                      : '未登录 · 点击粘贴 Cookie 登录',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white38),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 12),
              LiquidGlass(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white38, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '登录后发送的弹幕会真实出现在直播间（网页端同款协议）；粉丝数显示真实订阅数。',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
