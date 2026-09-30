import 'package:flutter/material.dart';
import 'package:live_app/core/notify_manager.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});
  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  bool _enabled = false;
  bool _checking = false;
  String _last = '';

  @override
  void initState() {
    super.initState();
    LiveNotifyManager.to.isEnabled().then((v) => setState(() => _enabled = v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('消息通知',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Row(children: [
                Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFB25E).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.notifications_active_outlined,
                        color: Color(0xFFFFB25E), size: 24)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('开播提醒',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('App 运行期间每 5 分钟检测 · 开播即发系统通知',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
                Switch(
                  value: _enabled,
                  activeColor: const Color(0xFFFF8800),
                  onChanged: (v) async {
                    setState(() => _enabled = v);
                    await LiveNotifyManager.to.setEnabled(v);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _checking
                  ? null
                  : () async {
                      setState(() => _checking = true);
                      final s = await LiveNotifyManager.to.checkNow();
                      if (mounted) setState(() => {_checking = false, _last = s});
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Center(
                    child: _checking
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2FF)))
                        : const Text('立即检测一次',
                            style: TextStyle(color: Color(0xFF00D2FF), fontSize: 14, fontWeight: FontWeight.w600))),
              ),
            ),
            if (_last.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(child: Text(_last, style: const TextStyle(color: Colors.white38, fontSize: 12))),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('说明', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text(
                    '· 只要 App 还在运行（前台或后台），每 5 分钟就会精准检测订阅主播状态。\n'
                    '· 发现主播从「未开播」变为「直播中」时，立即弹出高优先级系统通知。\n'
                    '· 点击通知可直接进入直播间。\n'
                    '· 首次开启会自动请求通知权限（Android 13+）。',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
