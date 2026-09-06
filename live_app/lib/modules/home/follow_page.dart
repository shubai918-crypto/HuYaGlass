import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../live_play/live_play_page.dart';
import 'follow_store.dart';

class _RoomExtra {
  final String screenshot;
  final String intro;
  final int fans;
  final String preview;
  _RoomExtra({this.screenshot = '', this.intro = '', this.fans = 0, this.preview = ''});
}

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  final HuyaStreamResolver _resolver = HuyaStreamResolver();
  final Map<String, _RoomExtra> _extras = {};
  bool _offlineByFans = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // ---------- 网页元数据抓取（粉丝数/截图/简介/预告） ----------
  String _unescape(String s) => s
      .replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
      .replaceAll('\\"', '"')
      .replaceAll('\\/', '/')
      .replaceAll('\\\\', '\\');

  Future<_RoomExtra> _fetchMeta(String roomId) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('https://www.huya.com/$roomId'))
          .timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
      req.headers.set('Referer', 'https://www.huya.com/');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final body =
          await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
      client.close(force: true);

      String? grab(String key) {
        final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"')
            .firstMatch(body);
        return m == null ? null : _unescape(m.group(1)!);
      }

      int? grabInt(String key) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(body);
        return m == null ? null : int.tryParse(m.group(1)!);
      }

      String pick(List<String> keys) {
        for (final k in keys) {
          final v = grab(k);
          if (v != null && v.isNotEmpty) return v;
        }
        return '';
      }

      int fans = 0;
      for (final k in ['totalCount', 'fansCount', 'fans', 'lUserCount', 'userCount']) {
        final v = grabInt(k);
        if (v != null && v > 0) { fans = v; break; }
      }

      return _RoomExtra(
        screenshot: pick(['screenshot', 'gameScreenshot']),
        intro: pick(['introduction', 'intro']),
        fans: fans,
        preview: pick(['liveIntro', 'roomIntro', 'live_intro', 'broadcastNotice', 'welcomeText']),
      );
    } catch (_) {
      return _RoomExtra();
    }
  }

  // ---------- 刷新 ----------
  Future<void> _refresh() async {
    final store = FollowStore.to;
    if (store.refreshing.value) return;
    store.refreshing.value = true;
    try {
      final snapshot = store.items.toList();
      for (final e in snapshot) {
        try {
          final results = await Future.wait([
            _resolver.resolveStream(e.roomId).timeout(const Duration(seconds: 6)),
            _fetchMeta(e.roomId),
          ]);
          final info = results[0] as dynamic;
          final meta = results[1] as _RoomExtra;
          if (info != null) {
            final idx = store.items.indexWhere((x) => x.roomId == e.roomId);
            if (idx >= 0) {
              store.items[idx] = FollowItem(
                roomId: e.roomId,
                name: info.streamerInfo.nickname.isNotEmpty
                    ? info.streamerInfo.nickname
                    : e.name,
                avatar: info.streamerInfo.avatar.isNotEmpty
                    ? info.streamerInfo.avatar
                    : e.avatar,
                isLive: info.isLive,
              );
            }
          }
          _extras[e.roomId] = meta;
        } catch (_) {}
      }
      await store.save();
    } finally {
      store.refreshing.value = false;
    }
    if (mounted) setState(() {});
  }

  void _open(FollowItem it) =>
      Get.to(() => const LivePlayPage(), arguments: {'roomId': it.roomId});

  Future<void> _unfollow(FollowItem it) async {
    final ok = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('取消订阅', style: TextStyle(color: Colors.white)),
            content: Text('不再关注「${it.name}」？',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('保留', style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text('取消订阅',
                      style: TextStyle(color: Color(0xFFE5484D)))),
            ],
          ),
        ) ??
        false;
    if (ok) await FollowStore.remove(it.roomId);
  }

  String _fmtFans(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
    Widget? right,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 6),
        Text('$title ($count)',
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (right != null) right,
      ]),
    );
  }

  // ★ 封面占位：渐变 + 图标，不再用头像放大
  Widget _coverPh() => Container(
        width: double.infinity,
        height: 130,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3A2A5E), Color(0xFF1A1A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv, color: Colors.white30, size: 40),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child:
                Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13))),
      );

  // ★ 正在直播：封面大卡
  Widget _liveCard(FollowItem it) {
    final ex = _extras[it.roomId];
    final cover = ex?.screenshot ?? '';
    final intro = ex?.intro ?? '';
    final fans = ex?.fans ?? 0;
    return GestureDetector(
      onTap: () => _open(it),
      onLongPress: () => _unfollow(it),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(children: [
              cover.isNotEmpty
                  ? Image.network(cover,
                      width: double.infinity, height: 130, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPh())
                  : _coverPh(),
              Positioned(
                left: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5484D).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('直播中',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(children: [
              Transform.translate(
                offset: const Offset(0, -16),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF16161E),
                  backgroundImage:
                      it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
                  child: it.avatar.isEmpty
                      ? const Icon(Icons.person, size: 22, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (fans > 0 || intro.isNotEmpty)
                      Text(
                        fans > 0 ? '粉丝数: ${_fmtFans(fans)}' : intro,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ★ 暂未开播：头像行 + 粉丝数 + 预告气泡
  Widget _offlineTile(FollowItem it) {
    final ex = _extras[it.roomId];
    final fans = ex?.fans ?? 0;
    final preview = ex?.preview ?? '';
    return GestureDetector(
      onTap: () => _open(it),
      onLongPress: () => _unfollow(it),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white10,
              backgroundImage: it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
              child: it.avatar.isEmpty
                  ? const Icon(Icons.person, size: 22, color: Colors.white54)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  fans > 0 ? '粉丝数: ${_fmtFans(fans)}' : '房间 ${it.roomId}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ]),
          if (preview.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CB7FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CB7FF).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('预告',
                      style: TextStyle(color: Color(0xFF7ECBFF), fontSize: 10)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(preview,
                      style: const TextStyle(
                          color: Color(0xFF7ECBFF), fontSize: 12, height: 1.4)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final all = FollowStore.to.items.toList();
      final live = all.where((e) => e.isLive).toList();
      var offline = all.where((e) => !e.isLive).toList();
      if (_offlineByFans) {
        offline = List.of(offline)
          ..sort((a, b) => (_extras[b.roomId]?.fans ?? 0)
              .compareTo(_extras[a.roomId]?.fans ?? 0));
      }
      return RefreshIndicator(
        color: const Color(0xFFFF8800),
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Row(children: [
              const Text('我的订阅',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GlassIconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFFF8800)),
                size: 40,
                onPressed: _refresh,
              ),
            ]),
            const SizedBox(height: 10),
            _sectionHeader(
              icon: Icons.live_tv,
              iconColor: const Color(0xFFFF8800),
              title: '正在直播',
              count: live.length,
              right: const Text('最近爱看',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            if (live.isEmpty) _empty('暂无开播主播') else ...live.map(_liveCard),
            const SizedBox(height: 16),
            _sectionHeader(
              icon: Icons.schedule,
              iconColor: const Color(0xFF4CB7FF),
              title: '暂未开播',
              count: offline.length,
              right: GestureDetector(
                onTap: () => setState(() => _offlineByFans = !_offlineByFans),
                child: Row(children: [
                  const Icon(Icons.sort, size: 14, color: Colors.white38),
                  Text(' 粉丝数量',
                      style: TextStyle(
                          color: _offlineByFans
                              ? const Color(0xFF4CB7FF)
                              : Colors.white38,
                          fontSize: 12)),
                ]),
              ),
            ),
            if (offline.isEmpty) _empty('暂无未开播主播') else ...offline.map(_offlineTile),
          ],
        ),
      );
    });
  }
}
