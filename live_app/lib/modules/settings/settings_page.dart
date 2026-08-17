import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/widgets/liquid_glass.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LiquidGlass(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('登录', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  '登录后可以发送弹幕和订阅主播',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlass(
            padding: const EdgeInsets.all(16),
            child: const Text('弹幕设置', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          LiquidGlass(
            padding: const EdgeInsets.all(16),
            child: const Text('关于', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
