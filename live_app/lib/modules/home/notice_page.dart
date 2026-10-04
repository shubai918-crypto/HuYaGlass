import 'package:flutter/material.dart';
import 'package:live_app/core/notify_manager.dart';
import 'home_page.dart';

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
    LiveNotifyManager.to.isEnabled().then((v) => setState(() => _enabled = v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kText),
        title: const Text('消息通知', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
            child: Row(children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFFFB25E).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFFFB25E), size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('开播提醒', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('App 运行期间每 5 分钟检测 · 开播即发系统通知', style: TextStyle(color: kSub, fontSize: 12)),
              ])),
              Switch(
                value: _enabled,
                activeColor: kAccent,
                onChanged: (v) async {
                  setState(() => _enabled = v);
                  await LiveNotifyManager.to.setEnabled(v);
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const Center(child: Icon(Icons.inbox_outlined, color: Color(0xFFC4C9CF), size: 48)),
          const SizedBox(height: 8),
          const Center(child: Text('暂无新消息', style: TextStyle(color: Color(0xFFA6ADB5), fontSize: 13))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('说明', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  '· 只要 App 还在运行（前台或后台），每 5 分钟就会精准检测订阅主播状态。\n'
                  '· 发现主播从「未开播」变为「直播中」时，立即弹出高优先级系统通知。\n'
                  '· 点击通知可直接进入直播间。\n'
                  '· 首次开启会自动请求通知权限（Android 13+）。',
                  style: TextStyle(color: kSub, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
