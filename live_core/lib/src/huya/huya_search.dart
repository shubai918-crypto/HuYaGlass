import 'dart:convert';
import 'dart:io';

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

/// 虎牙搜索（参考 dtv_mobile：HTTP GET + UA/Referer + JSON 解析）
class HuyaSearchApi {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0';

  static String _strip(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  /// 关键词搜索主播
  static Future<List<HuyaSearchItem>> search(String keyword) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('https://search.huya.com/'
          '?m=Search&do=getSearchContent'
          '&q=${Uri.encodeComponent(keyword)}'
          '&typ=-5&rows=20&v=1&uid=0&live=0&appid=1001');
      final req = await client.getUrl(uri);
      req.headers
        ..set(HttpHeaders.userAgentHeader, _ua)
        ..set(HttpHeaders.refererHeader, 'https://www.huya.com/')
        ..set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
      final resp =
          await req.close().timeout(const Duration(seconds: 8));
      final text = await resp.transform(utf8.decoder).join();
      return _parseSearch(text);
    } finally {
      client.close(force: true);
    }
  }

  static List<HuyaSearchItem> _parseSearch(String text) {
    final out = <HuyaSearchItem>[];
    final root = jsonDecode(text);
    if (root is! Map) return out;

    List? docs;
    final response = root['response'];
    if (response is Map) {
      final one = response['1'];
      if (one is Map && one['docs'] is List) {
        docs = one['docs'] as List;
      } else if (response['docs'] is List) {
        docs = response['docs'] as List;
      } else {
        for (final v in response.values) {
          if (v is Map && v['docs'] is List) {
            docs = v['docs'] as List;
            break;
          }
        }
      }
    }
    if (docs == null) return out;

    for (final d in docs) {
      if (d is! Map) continue;
      final roomId = '${d['room_id'] ?? d['roomid'] ?? d['gid'] ?? ''}';
      final nick = _strip('${d['game_nick'] ?? d['nick'] ?? ''}');
      if (roomId.isEmpty || nick.isEmpty) continue;
      out.add(HuyaSearchItem(
        roomId: roomId,
        nickname: nick,
        title: _strip('${d['game_introduction'] ?? d['game_title'] ?? ''}'),
        avatarUrl:
            '${d['game_avatarUrl180'] ?? d['game_avatarUrl'] ?? d['avatar180'] ?? ''}',
        isLive: (d['game_is_on'] ?? 0) == 1,
        totalCount: d['game_total_count'] is num
            ? (d['game_total_count'] as num).toInt()
            : 0,
      ));
    }
    return out;
  }

  /// 房间号直查（校验 + 取昵称/头像）
  static Future<HuyaSearchItem?> getRoom(String roomId) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://www.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId');
      final req = await client.getUrl(uri);
      req.headers
        ..set(HttpHeaders.userAgentHeader, _ua)
        ..set(HttpHeaders.refererHeader, 'https://www.huya.com/');
      final resp =
          await req.close().timeout(const Duration(seconds: 8));
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
        avatarUrl: '${data['avatar180'] ?? data['avatar'] ?? ''}',
        isLive: data['isOn'] == 1 || data['isLive'] == true || hasStream,
        totalCount:
            data['totalCount'] is num ? (data['totalCount'] as num).toInt() : 0,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
