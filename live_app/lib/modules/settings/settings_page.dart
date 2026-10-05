import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_app/core/app_settings.dart';

import '../home/home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kText),
          onPressed: () => Get.back(),
        ),
        title: const Text('设置', style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('播放设置'),
          const SizedBox(height: 8),
          _group([
            _row(Icons.play_circle_outline, kAccent, '播放设置', '清晰度与线路自动优选'),
            _divider(),
            _row(Icons.route_outlined, const Color(0xFF4CB7FF), '网络线路', '优先使用网页 FLV 直连'),
          ]),
          const SizedBox(height: 20),
          _section('开发者'),
          const SizedBox(height: 8),
          _group([
            // ★ 仅保留 AppSettings 中真实存在的 debugEnabled
            Obx(() => _switchRow(
                  '调试模式',
                  '显示协议日志与调试信息',
                  AppSettings.to.debugEnabled.value,
                  (v) => AppSettings.to.setDebug(v),
                )),
          ]),
          const SizedBox(height: 20),
          _section('关于'),
          const SizedBox(height: 8),
          _group([
            _row(Icons.info_outline, const Color(0xFF4CB7FF), '版本', '1.0.0 (build 1)'),
            _divider(),
            _row(Icons.code, const Color(0xFF8A9099), '开发者', '白薯 + qwen3.8Max'),
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

  // ★ 使用 GlassSwitch
  Widget _switchRow(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kSub, fontSize: 12)),
          ]),
        ),
        GlassSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: kAccent,
          useOwnLayer: true,
          quality: GlassQuality.premium,
        ),
      ]),
    );
  }

  Widget _row(IconData icon, Color color, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kSub, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
