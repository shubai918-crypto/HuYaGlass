import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'live_play_controller.dart';

class LivePlayPage extends StatefulWidget {
  const LivePlayPage({super.key});
  @override
  State<LivePlayPage> createState() => _LivePlayPageState();
}

class _LivePlayPageState extends State<LivePlayPage>
    with SingleTickerProviderStateMixin {
  late final LivePlayController c = Get.put(LivePlayController());
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    Get.delete<LivePlayController>();
    super.dispose();
  }

  String _fmt(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => c.isFullscreen.value ? _buildFullscreen() : _buildPortrait(context));
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(child: c.videoHost(true)),
    );
  }

  Widget _buildPortrait(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Column(children: [
        SizedBox(height: top),
        _header(),
        AspectRatio(aspectRatio: 16 / 9, child: c.videoHost(false)),
        _tabs(),
        Expanded(
  child: TabBarView(controller: _tab, children: [
    _DanmakuList(c: c),
    _DetailTab(c: c),
  ]),
),
        _bottomBar(),
      ]),
    );
  }

  Widget _header() {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white10,
              backgroundImage: c.streamerAvatar.value.isNotEmpty
                  ? NetworkImage(c.streamerAvatar.value)
                  : null,
              child: c.streamerAvatar.value.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        c.streamerName.value.isEmpty
                            ? '—'
                            : c.streamerName.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('粉丝 ${_fmt(c.fansCount.value)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
            ),
            GestureDetector(
              onTap: c.toggleFollow,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0x33E5484D),
                    border: Border.all(color: const Color(0xFFE5484D)),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c.isFollowed.value ? '已订阅' : '订阅',
                    style:
                        const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Colors.white10, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: Colors.white70, size: 20),
              ),
            ),
          ]),
        ));
  }

  Widget _tabs() {
    return Container(
      color: const Color(0xFF101018),
      child: TabBar(
        controller: _tab,
        indicatorColor: const Color(0xFF00D2FF),
        labelColor: const Color(0xFF00D2FF),
        unselectedLabelColor: Colors.white54,
        tabs: const [Tab(text: '弹幕'), Tab(text: '主播详情')],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: const Color(0xFF101018),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 34,
          child: Obx(() => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.qualities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final q = c.qualities[i];
                  final sel = q.name == c.currentQuality.value;
                  return GestureDetector(
                    onTap: () => c.switchQuality(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00D2FF).withOpacity(0.12)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(q.name,
                          style: TextStyle(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white60,
                              fontSize: 12)),
                    ),
                  );
                },
              )),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: Obx(() => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.lines.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = i == c.currentLine.value;
                  return GestureDetector(
                    onTap: () => c.switchLine(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00D2FF).withOpacity(0.12)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(14)),
                      child: Text('线路${i + 1}',
                          style: TextStyle(
                              color: sel
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white60,
                              fontSize: 12)),
                    ),
                  );
                },
              )),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22)),
              child: TextField(
                controller: c.inputController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    hintText: '发送弹幕...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none),
                onSubmitted: (t) => c.sendDanmaku(t),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => c.sendDanmaku(c.inputController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Color(0xFF00D2FF), shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ================= 弹幕列表 =================
class _DanmakuList extends StatefulWidget {
  final LivePlayController? c;
  const _DanmakuList({required this.c});
  @override
  State<_DanmakuList> createState() => _DanmakuListState();
}

class _DanmakuListState extends State<_DanmakuList> {
  final ScrollController _sc = ScrollController();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.c!.danmakuList.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients && _sc.position.maxScrollExtent > 0) {
          _sc.jumpTo(_sc.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c!;
    return Obx(() {
      if (c.danmakuList.isEmpty) {
        return Center(
            child: Text(c.danmakuStatus.value,
                style: const TextStyle(color: Colors.white24)));
      }
      final list = c.danmakuList;
      return ListView.builder(
        controller: _sc,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: list.length,
        itemBuilder: (_, i) => _item(c, list[i]),
      );
    });
  }

  Widget _item(LivePlayController c, DanmakuMessage m) {
    return GestureDetector(
      onTap: () => c.showUserInfo(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (m.fansName.isNotEmpty)
                Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF8800).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${m.fansLevel} ${m.fansName}',
                        style: const TextStyle(
                            color: Color(0xFFFF8800), fontSize: 10))),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text:
                        '${m.nickname.isEmpty ? "神秘用户" : m.nickname}: ',
                    style: TextStyle(
                        color: Color(m.fontColor),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                TextSpan(
                    text: m.content,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ])),
            ]),
      ),
    );
  }
}

// ================= 主播详情 =================
class _DetailTab extends StatelessWidget {
  final LivePlayController? c;
  const _DetailTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final c = this.c!;
    return Obx(() => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _card(),
              child: Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white10,
                  backgroundImage: c.streamerAvatar.value.isNotEmpty
                      ? NetworkImage(c.streamerAvatar.value)
                      : null,
                  child: c.streamerAvatar.value.isEmpty
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            c.streamerName.value.isEmpty
                                ? '—'
                                : c.streamerName.value,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            '房间号 ${c.roomId} · ${c.isLive.value ? "直播中" : "未开播"}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: c.isLive.value
                          ? const Color(0x33E5484D)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(c.isLive.value ? 'LIVE' : 'OFF',
                      style: TextStyle(
                          color: c.isLive.value
                              ? const Color(0xFFE5484D)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: _card(),
              child: Row(children: [
                _stat(_fmt(c.fansCount.value), '粉丝'),
                _divider(),
                _stat(_fmt(c.heatCount.value), '热度'),
                _divider(),
                _stat('${c.qualities.length} 档', '清晰度'),
              ]),
            ),
            if (c.isLive.value && c.liveDurationText.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _card(),
                child: Row(children: [
                  const Icon(Icons.schedule, color: Color(0xFF7ED97E)),
                  const SizedBox(width: 10),
                  const Text('开播时长',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Text(c.liveDurationText.value,
                      style: const TextStyle(
                          color: Color(0xFF7ED97E),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            if (!c.isLive.value && c.lastLiveText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _card(),
                child: Row(children: [
                  const Icon(Icons.history, color: Colors.white54),
                  const SizedBox(width: 10),
                  const Text('上次开播',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Text(c.lastLiveText,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                ]),
              ),
            ],
            if (c.roomTitle.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _card(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('直播预告',
                          style: TextStyle(
                              color: Color(0xFFFF8800),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(c.roomTitle.value,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
              ),
            ],
          ],
        ));
  }

  Widget _stat(String v, String label) {
    return Expanded(
      child: Column(children: [
        Text(v,
            style: const TextStyle(
                color: Color(0xFF00D2FF),
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: Colors.white12);

  BoxDecoration _card() => BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      );

  String _fmt(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }
}
