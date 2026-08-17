import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/live_room.dart';

/// 虎牙 HTTP API（搜索、订阅、粉丝数）
class HuyaApi {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 搜索直播间
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    try {
      final url = Uri.parse(
        'https://search.huya.com/h5/search?keyword=${Uri.encodeComponent(keyword)}&pageNo=$page&pageSize=20',
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
          title: d['room_name'] ?? '',
          streamerName: d['game_nick'] ?? '',
          streamerAvatar: d['game_avatar'] ?? '',
          fansCount: d['fans_count'] ?? 0,
          isLive: (d['live_status'] ?? 0) == 2,
          coverUrl: d['screenshot'] ?? '',
          categoryName: d['game_name'] ?? '',
          presenterUid: d['uid'] ?? 0,
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

  /// 获取分类列表（参考 dtv_mobile 中的虎牙分类 JSON）
  Future<List<HuyaCategory>> getCategories() async {
    // 这里可以硬编码常用分类或从 API 获取
    return [
      HuyaCategory(id: '1', name: '英雄联盟'),
      HuyaCategory(id: '2', name: '王者荣耀'),
      HuyaCategory(id: '3', name: '和平精英'),
      HuyaCategory(id: '5', name: '主机游戏'),
      HuyaCategory(id: '8', name: '娱乐'),
      HuyaCategory(id: '1663', name: '户外'),
      HuyaCategory(id: '2135', name: '美食'),
      HuyaCategory(id: '2165', name: '音乐'),
    ];
  }
}

class HuyaCategory {
  final String id;
  final String name;

  HuyaCategory({required this.id, required this.name});
}
