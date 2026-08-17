import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/live_room.dart';

class HuyaApi {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 搜索直播间
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    try {
      final url = Uri.parse(
        'https://search.huya.com/h5/search?keyword=$keyword&pageNo=$page&pageSize=20',
      );
      final response = await http.get(url, headers: {
        'User-Agent': _userAgent,
        'Referer': 'https://www.huya.com/',
      });

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['response'] as Map<String, dynamic>?;
      final docs = data?['docs'] as List<dynamic>? ?? [];

      return docs.map((doc) {
        final d = doc as Map<String, dynamic>;
        return LiveRoom(
          roomId: '${d['room_id'] ?? ''}',
          title: d['game_nick'] ?? d['room_name'] ?? '',
          streamerName: d['game_nick'] ?? '',
          streamerAvatar: d['game_avatar'] ?? '',
          fansCount: d['fans_count'] ?? 0,
          isLive: (d['live_status'] ?? 0) == 2,
          coverUrl: d['screenshot'] ?? '',
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取主播粉丝数
  Future<int> getFansCount(String roomId) async {
    try {
      final url = 'https://m.huya.com/$roomId';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': _userAgent,
      });

      if (response.statusCode != 200) return 0;

      final regex = RegExp(r'"lFansCount"\s*:\s*(\d+)');
      final match = regex.firstMatch(response.body);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 订阅主播 (需要登录态 Cookie)
  Future<bool> subscribePresenter({
    required int presenterUid,
    required String cookie,
  }) async {
    try {
      final url = Uri.parse('https://favorite.huya.com/fav/subscribe');
      final response = await http.post(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Cookie': cookie,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://www.huya.com/',
        },
        body: 'presenterUid=$presenterUid',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['status'] == 200;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 取消订阅
  Future<bool> unsubscribePresenter({
    required int presenterUid,
    required String cookie,
  }) async {
    try {
      final url = Uri.parse('https://favorite.huya.com/fav/unsubscribe');
      final response = await http.post(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Cookie': cookie,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://www.huya.com/',
        },
        body: 'presenterUid=$presenterUid',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['status'] == 200;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
