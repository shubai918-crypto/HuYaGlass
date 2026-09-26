import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});
  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _enabled = p.getBool('notice_on') ?? false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('消息通知', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFFB25E).withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.notifications_outlined, color: Color(0xFFFFB25E), size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('开启消息通知', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('订阅主播开播时提醒我', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
            ])),
            Switch(
              value: _enabled,
              activeColor: const Color(0xFFFF8800),
              onChanged: (v) async {
                setState(() => _enabled = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('notice_on', v);
              },
            ),
          ]),
        ),
        const SizedBox(height: 32),
        const Center(child: Icon(Icons.inbox_outlined, color: Colors.white24, size: 48)),
        const SizedBox(height: 8),
        const Center(child: Text('暂无新消息', style: TextStyle(color: Colors.white38, fontSize: 13))),
      ]),
    );
  }
}
