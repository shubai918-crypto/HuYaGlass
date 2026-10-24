import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import '../live_play/live_play_page.dart';
import 'follow_store.dart';
import 'home_page.dart';

class _RoomExtra {
  final String screenshot;
  final String intro;
  final int fans;
  final String fansText;
  final String preview;
  _RoomExtra({this.screenshot = '', this.intro = '', this.fans = 0, this.fansText = '', this.preview = ''});
}

class _PreviewCache {
  final String text;
  final int ts;
  _PreviewCache(this.text, this.ts);
}

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  final HuyaStreamResolver _resolver = HuyaStreamResolver();
  final Map<String, _RoomExtra> _extras = {};
  final Map<String, _PreviewCache> _previewCache = {};
  bool _offlineByFans = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  String _unescape(String s) => s
      .replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
      .replaceAll('\\"', '"')
      .replaceAll('\\/', '/')
      .replaceAll('\\\\', '\\');

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ');

  int _parseFans(String s) {
    s = s.trim();
    if (s.isEmpty) return 0;
    double ratio = 1;
    if (s.contains('亿')) { ratio = 100000000; s = s.replaceAll('亿', ''); }
    else if (s.contains('万')) { ratio = 10000; s = s.replaceAll('万', ''); }
    final v = double.tryParse(s.trim());
    return v == null ? 0 : (v * ratio).round();
  }

  String _fmtFans(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  Future<void> _runPool<T>(List<T> items, int concurrency, Future<void> Function(T) task) async {
    if (items.isEmpty) return;
    var next = 0;
    await Future.wait(List.generate(concurrency, (_) async {
      while (true) {
        final i = next++;
        if (i >= items.length) return;
        try { await task(items[i]); } catch (_) {}
      }
    }));
  }

  Future<_RoomExtra> _fetchHttpMeta(String roomId) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse('https://www.huya.com/$roomId')).timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
      req.headers.set('Referer', 'https://www.huya.com/');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final body = await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
      client.close(force: true);
      final nbody = body.replaceAll('\\/', '/');
      String? grab(String key) {
        final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(body);
        return m == null ? null : _unescape(m.group(1)!);
      }
      int grabInt(String key) {
        var m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(body);
        if (m != null) return int.tryParse(m.group(1)!) ?? 0;
        m = RegExp('"$key"\\s*:\\s*"(\\d+)"').firstMatch(body);
        if (m != null) return int.tryParse(m.group(1)!) ?? 0;
        return 0;
      }
      String pick(List<String> keys) {
        for (final k in keys) { final v = grab(k); if (v != null && v.isNotEmpty) return v; }
        return '';
      }
      String cover = '';
      final cm = RegExp(r'''https?://live-cover\.msstatic\.com[^"'\s<>]+?\.jpg''').firstMatch(nbody);
      if (cm != null) cover = _decodeEntities(cm.group(0)!);
      if (cover.isEmpty) cover = pick(['screenshot', 'sScreenshot', 'gameScreenshot']);
      String fansText = '';
      final fm = RegExp(r'id="activityCount"[^>]*>([^<]+)<').firstMatch(body);
      if (fm != null) fansText = _decodeEntities(fm.group(1)!).trim();
      int fans = _parseFans(fansText);
      if (fans <= 0) {
        for (final k in ['totalCount', 'fansCount', 'fans', 'followerCount', 'lUserCount']) {
          final v = grabInt(k);
          if (v > 0) { fans = v; break; }
        }
      }
      return _RoomExtra(screenshot: cover, intro: pick(['introduction', 'roomIntro', 'intro']), fans: fans, fansText: fansText);
    } catch (_) {
      return _RoomExtra();
    }
  }

  Future<void> _refresh() async {
    final store = FollowStore.to;
    if (store.refreshing.value) return;
    store.refreshing.value = true;
    try {
      final snapshot = store.items.toList();
      final ids = <String, List<int>>{};
      final offlineRooms = <String>[];
      final now0 = DateTime.now().millisecondsSinceEpoch;
      await _runPool(snapshot, 4, (e) async {
        final results = await Future.wait<Object?>([
          _resolver.resolveStream(e.roomId).timeout(const Duration(seconds: 6)),
          _fetchHttpMeta(e.roomId).timeout(const Duration(seconds: 6)),
        ]);
        final info = results[0];
        var meta = (results[1] as _RoomExtra?) ?? _RoomExtra();
        var isLive = false; var top = 0; var sub = 0; var uid = 0;
        if (info != null) {
          final d = info as dynamic;
          isLive = d.isLive == true;
          try { uid = (d.ayyuid as int?) ?? 0; } catch (_) {}
          try { top = (d.topSid as int?) ?? 0; if (top == 0) top = (d.presenterUid as int?) ?? 0; } catch (_) {}
          try { sub = (d.subSid as int?) ?? 0; } catch (_) {}
          final idx = store.items.indexWhere((x) => x.roomId == e.roomId);
          if (idx >= 0) {
            store.items[idx] = FollowItem(
              roomId: e.roomId,
              name: d.streamerInfo.nickname.isNotEmpty ? d.streamerInfo.nickname : e.name,
              avatar: d.streamerInfo.avatar.isNotEmpty ? d.streamerInfo.avatar : e.avatar,
              isLive: isLive,
            );
          }
        }
        ids[e.roomId] = [top, sub, uid];
        if (!isLive && uid > 0) offlineRooms.add(e.roomId);
        final pc = _previewCache[e.roomId];
        if (!isLive && pc != null && now0 - pc.ts < 300000) {
          meta = _RoomExtra(screenshot: meta.screenshot, intro: meta.intro, fans: meta.fans, fansText: meta.fansText, preview: pc.text);
        }
        _extras[e.roomId] = meta;
        if (mounted) setState(() {});
      });
      final pending = offlineRooms.where((rid) => (_previewCache[rid] == null || now0 - _previewCache[rid]!.ts >= 300000)).toList();
      if (pending.isNotEmpty && mounted) {
        final client = HuyaDanmakuClient();
        try {
          final f = ids[pending.first]!;
          await client.connect(topSid: f[0], subSid: f[1], uid: f[2], roomIdStr: pending.first);
          await client.waitForReady(timeoutMs: 3000);
          for (final rid in pending) {
            if (!mounted) break;
            final uid = (ids[rid]?.length ?? 0) > 2 ? ids[rid]![2] : 0;
            final s = await client.requestScheduleFor(uid, timeout: const Duration(seconds: 3));
            if (s.isNotEmpty) {
              _previewCache[rid] = _PreviewCache(s, DateTime.now().millisecondsSinceEpoch);
              final ex = _extras[rid];
              if (ex != null) {
                _extras[rid] = _RoomExtra(screenshot: ex.screenshot, intro: ex.intro, fans: ex.fans, fansText: ex.fansText, preview: s);
                if (mounted) setState(() {});
              }
            }
          }
        } catch (_) {} finally {
          client.disconnect();
        }
      }
      await store.save();
    } finally {
      store.refreshing.value = false;
      if (mounted) setState(() {});
    }
  }

  void _open(FollowItem it) => goLive(it.roomId, nickname: it.name, avatarUrl: it.avatar);

  Future<void> _unfollow(FollowItem it) async {
    await FollowStore.remove(it.roomId);
    if (mounted) Get.snackbar('已取消订阅', it.name, snackPosition: SnackPosition.BOTTOM);
  }

  void _reorderLive(int oldIndex, int newIndex) {
    final store = FollowStore.to;
    List<int> liveIdx() => [for (int i = 0; i < store.items.length; i++) if (store.items[i].isLive) i];
    var idx = liveIdx();
    if (oldIndex >= idx.length) return;
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    final item = store.items.removeAt(idx[oldIndex]);
    idx = liveIdx();
    final globalNew = ni < idx.length ? idx[ni] : store.items.length;
    store.items.insert(globalNew, item);
    store.save();
    setState(() {});
  }

  List<GlassSwipeAction> _trailing(FollowItem it) => [
        GlassSwipeAction(
          icon: const Icon(Icons.favorite_border, color: Colors.white),
          label: const Text('取关'),
          isDestructive: true,
          onTap: () => _unfollow(it),
        ),
      ];

  List<Widget> _contextActions(FollowItem it) => [
        GlassContextMenuAction(child: const Text('进入直播间'), icon: const Icon(Icons.play_arrow, color: Color(0xFFFF8800)), onPressed: () => _open(it)),
        GlassContextMenuAction(child: const Text('复制房间链接'), icon: const Icon(Icons.link), onPressed: () {
          Clipboard.setData(ClipboardData(text: 'https://www.huya.com/${it.roomId}'));
          Get.snackbar('提示', '已复制', snackPosition: SnackPosition.BOTTOM);
        }),
        GlassContextMenuAction(child: const Text('取消订阅'), icon: const Icon(Icons.block), isDestructive: true, onPressed: () => _unfollow(it)),
      ];

  String _fansLabel(_RoomExtra? ex) {
    if (ex == null) return '';
    if (ex.fansText.isNotEmpty) return ex.fansText;
    if (ex.fans > 0) return _fmtFans(ex.fans);
    return '';
  }

  Widget _sectionHeader({required IconData icon, required Color iconColor, required String title, required int count, Widget? right}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 6),
        Text('$title ($count)', style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (right != null) right,
      ]),
    );
  }

  Widget _coverThumb(String url) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url.isNotEmpty
            ? Image.network(url, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbPh())
            : _thumbPh(),
      );

  Widget _thumbPh() => Container(
        width: 64, height: 64,
        color: const Color(0xFFF2F3F5),
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv, color: Color(0xFFC4C9CF), size: 24),
      );

// ★ 玻璃行：直播项（长按=拖拽排序，不再挂上下文菜单，避免手势冲突）
  Widget _liveTile(FollowItem it, int index) {
    final ex = _extras[it.roomId];
    final fansLabel = _fansLabel(ex);
    return GlassListTile(
      key: ValueKey(it.roomId),
      reorderIndex: index,
      canReorder: true,
      leading: _coverThumb(ex?.screenshot ?? ''),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(fansLabel.isNotEmpty ? '粉丝 $fansLabel' : (ex?.intro ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kSub, fontSize: 12)),
      ]),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(8)),
        child: const Text('直播中', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
      onTap: () => _open(it),
      trailingSwipeActions: _trailing(it),
      // ★ 注意：这里不再写 contextMenuActions，长按留给拖拽排序
    );
  }

  // ★ 玻璃行：离线项（不可拖拽，保留滑动/菜单）
  Widget _offlineTile(FollowItem it) {
    final ex = _extras[it.roomId];
    final fansLabel = _fansLabel(ex);
    final preview = ex?.preview ?? '';
    return GlassListTile(
      key: ValueKey(it.roomId),
      canReorder: false,
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFF2F3F5),
        backgroundImage: it.avatar.isNotEmpty ? NetworkImage(it.avatar) : null,
        child: it.avatar.isEmpty ? const Icon(Icons.person, size: 24, color: Color(0xFFA6ADB5)) : null,
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(preview.isNotEmpty ? '预告: $preview' : (fansLabel.isNotEmpty ? '粉丝 $fansLabel' : '房间 ${it.roomId}'),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kSub, fontSize: 12)),
      ]),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFC4C9CF)),
      onTap: () => _open(it),
      trailingSwipeActions: _trailing(it),
      contextMenuActions: _contextActions(it),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final all = FollowStore.to.items.toList();
      final live = all.where((e) => e.isLive).toList();
      var offline = all.where((e) => !e.isLive).toList();
      if (_offlineByFans) {
        offline = List.of(offline)..sort((a, b) => (_extras[b.roomId]?.fans ?? 0).compareTo(_extras[a.roomId]?.fans ?? 0));
      }
      return RefreshIndicator(
        color: kAccent,
        onRefresh: _refresh,
        child: GlassScrollEdgeEffect(
          style: GlassScrollEdgeStyle.soft,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
            children: [
              Row(children: [
                const Text('我的订阅', style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                GlassIconButton(icon: const Icon(Icons.refresh, color: kAccent), size: 40,
                    settings: LiquidGlassSettings(glassColor: const Color(0x99F2F2F7), thickness: 20, blur: 4,
                        lightIntensity: 0.3, specularSharpness: GlassSpecularSharpness.medium, shadowElevation: 1.0),
                    onPressed: _refresh),
              ]),
              const SizedBox(height: 12),
              _sectionHeader(icon: Icons.live_tv, iconColor: kAccent, title: '正在直播', count: live.length,
                  right: const Text('长按拖拽排序', style: TextStyle(color: kSub, fontSize: 11))),
              if (live.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('暂无开播主播', style: TextStyle(color: Color(0xFFA6ADB5), fontSize: 13))))
              else
                // ★ 玻璃版拖拽：grouped 默认 shrinkWrap + NeverScrollable，可直接嵌入 ListView
                GlassReorderableList.grouped(
                  itemCount: live.length,
                  onReorderItem: _reorderLive,
                  itemBuilder: (context, index) => _liveTile(live[index], index),
                ),
              const SizedBox(height: 20),
              _sectionHeader(icon: Icons.schedule, iconColor: const Color(0xFF00B8D4), title: '暂未开播', count: offline.length,
                  right: GestureDetector(
                    onTap: () => setState(() => _offlineByFans = !_offlineByFans),
                    child: Row(children: [
                      Icon(Icons.sort, size: 14, color: _offlineByFans ? const Color(0xFF00B8D4) : kSub),
                      Text(' 粉丝数量', style: TextStyle(color: _offlineByFans ? const Color(0xFF00B8D4) : kSub, fontSize: 12)),
                    ]),
                  )),
              if (offline.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('暂无未开播主播', style: TextStyle(color: Color(0xFFA6ADB5), fontSize: 13))))
              else
                GlassReorderableList.grouped(
                  itemCount: offline.length,
                  itemBuilder: (context, index) => _offlineTile(offline[index]),
                ),
            ],
          ),
        ),
      );
    });
  }
}
