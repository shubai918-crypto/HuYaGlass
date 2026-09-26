import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('关于 HuyaLive', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 12),
        Center(child: Container(
            width: 84, height: 84,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF8800), Color(0xFFFF5A00)]), borderRadius: BorderRadius.all(Radius.circular(24))),
            child: const Icon(Icons.live_tv, color: Colors.white, size: 44))),
        const SizedBox(height: 16),
        const Center(child: Text('HuyaLive', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))),
        const SizedBox(height: 6),
        const Center(child: Text('液态玻璃版 · v1.0.0', style: TextStyle(color: Colors.white54, fontSize: 13))),
        const SizedBox(height: 28),
        _card('开发者', '白薯 + qwen3.8Max', Icons.code_outlined, const Color(0xFF00D2FF)),
        const SizedBox(height: 12),
        _card('UI 框架', 'liquid_glass_widgets · iOS 26 液态玻璃', Icons.brush_outlined, const Color(0xFFFFB25E)),
        const SizedBox(height: 12),
        _card('项目参考', 'pure_live / dtv', Icons.favorite_outline, const Color(0xFFFF6B9C)),
        const SizedBox(height: 28),
        const Center(child: Text('用 ❤ 为虎牙主播打造', style: TextStyle(color: Colors.white30, fontSize: 12))),
      ]),
    );
  }

  Widget _card(String title, String sub, IconData icon, Color color) {
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
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
        ])),
      ]),
    );
  }
}
