import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 虎牙搜索结果条目
class HuyaSearchItem {
  final String roomId;
  final String nickname;
  final String title;
  final String avatarUrl;
  final bool isLive;
  final int totalCount;

  const HuyaSearchItem({
    required this.roomId,
    required this.nickname,
    this.title = '',
    this.avatarUrl = '',
    this.isLive = false,
    this.totalCount = 0,
  });
}

/// 虎牙搜索（1:1 移植 dtv HuyaSearchApiAndroid）
class HuyaSearchApi {
  /// 关键词搜索主播
  static Future<List<HuyaSearchItem>> search(String keyword,
      {int page = 1}) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];

    final start = (((page - 1) < 0 ? 0 : (page - 1)) * 20).toString();
    final uri = Uri.parse('https://search.cdn.huya.com/').replace(
      queryParameters: {
        'm': 'Search',
        'do': 'getSearchContent',
        'q': trimmed,
        'uid': '0',
        'v': '1',
        'typ': '-5',
        'livestate': '0',
        'rows': '20',
        'start': start,
      },
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'Mozilla/5.0')
        ..set(HttpHeaders.refererHeader, 'https://www.huya.com/search/')
        ..set('Origin', 'https://www.huya.com')
        ..set(HttpHeaders.acceptHeader, '*/*');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final text = await resp.transform(utf8.decoder).join();
      final items = _parse(text);
      debugPrint('[HuyaSearch] ${items.length} 条');
      return items;
    } catch (e) {
      debugPrint('[HuyaSearch] 失败: $e');
      return [];
    } finally {
      client.close(force: true);
    }
  }

  static List<HuyaSearchItem> _parse(String text) {
    final out = <HuyaSearchItem>[];
    final root = jsonDecode(text);
    if (root is! Map) return out;
    final response = root['response'];
    if (response is! Map) return out;
    final one = response['1'];
    if (one is! Map) return out;
    final docs = one['docs'];
    if (docs is! List) return out;

    for (final d in docs) {
      if (d is! Map) continue;
      final roomId = '${d['room_id'] ?? ''}';
      if (roomId.isEmpty || roomId == '0' || roomId == 'null') continue;

      final name = _strip('${d['game_nick'] ?? ''}');
      final title = _strip('${d['live_intro'] ?? ''}');
      final liveRaw = d['gameLiveOn'];

      out.add(HuyaSearchItem(
        roomId: roomId,
        nickname: name.isEmpty ? '虎牙主播' : name,
        title: title.isEmpty ? '暂无标题' : title,
        avatarUrl: _normalizeUrl('${d['game_avatarUrl180'] ?? ''}'),
        isLive: liveRaw == true || '$liveRaw' == 'true' || '$liveRaw' == '1',
      ));
    }
    return out;
  }

  /// // 开头补 https:
  static String _normalizeUrl(String u) {
    if (u.isEmpty) return '';
    return u.startsWith('//') ? 'https:$u' : u;
  }

  /// 去掉 <em> 高亮标签
  static String _strip(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  /// 房间号直查
  static Future<HuyaSearchItem?> getRoom(String roomId) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(
          'https://www.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'Mozilla/5.0')
        ..set(HttpHeaders.refererHeader, 'https://www.huya.com/');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final text = await resp.transform(utf8.decoder).join();
      final root = jsonDecode(text);
      if (root is! Map || root['status'] != 200) return null;
      final data = root['data'];
      if (data is! Map) return null;
      final hasStream = data['stream'] is Map;
      return HuyaSearchItem(
        roomId: roomId,
        nickname: _strip('${data['nick'] ?? ''}'),
        title: _strip('${data['introduction'] ?? data['slogan'] ?? ''}'),
        avatarUrl: _normalizeUrl('${data['avatar180'] ?? data['avatar'] ?? ''}'),
        isLive: data['isOn'] == 1 || data['isLive'] == true || hasStream,
        totalCount: data['totalCount'] is num
            ? (data['totalCount'] as num).toInt()
            : 0,
      );
    } catch (e) {
      debugPrint('[HuyaSearch] getRoom 失败: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
