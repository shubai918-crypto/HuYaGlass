import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/live_room.dart';

/// 虎牙订阅/关注功能
/// 参考: room_normal_da107fb0.js 中的 GetUserSubscribeToInfoListRsp
class HuyaFollowService {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final String _cookie;

  HuyaFollowService({required String cookie}) : _cookie = cookie;

  /// 订阅主播
  /// 对应 ModRelationReq.iOp = 1
  Future<FollowResult> subscribe({
    required int presenterUid,
    required String source,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://mp.huya.com/cache/subscribe'),
        headers: {
          'User-Agent': _userAgent,
          'Cookie': _cookie,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://www.huya.com/',
          'Origin': 'https://www.huya.com',
        },
        body: {
          'pid': presenterUid.toString(),
          'source': source,
          'op': '1',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] ?? json['code'] ?? -1;
        if (status == 200 || status == 0) {
          return FollowResult(success: true, message: '订阅成功');
        }
        return FollowResult(success: false, message: json['message'] ?? '订阅失败');
      }
      return FollowResult(success: false, message: 'HTTP ${response.statusCode}');
    } catch (e) {
      return FollowResult(success: false, message: '网络错误: $e');
    }
  }

  /// 取消订阅
  /// 对应 ModRelationReq.iOp = 2
  Future<FollowResult> unsubscribe({
    required int presenterUid,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://mp.huya.com/cache/subscribe'),
        headers: {
          'User-Agent': _userAgent,
          'Cookie': _cookie,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://www.huya.com/',
          'Origin': 'https://www.huya.com',
        },
        body: {
          'pid': presenterUid.toString(),
          'op': '2',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] ?? json['code'] ?? -1;
        if (status == 200 || status == 0) {
          return FollowResult(success: true, message: '已取消订阅');
        }
        return FollowResult(success: false, message: json['message'] ?? '操作失败');
      }
      return FollowResult(success: false, message: 'HTTP ${response.statusCode}');
    } catch (e) {
      return FollowResult(success: false, message: '网络错误: $e');
    }
  }

  /// 获取已订阅主播列表
  /// 参考: GetUserSubscribeToInfoListRsp
  /// 结构: vItems[], iTotal, iPageSize, iPageIndex
  Future<List<LiveRoom>> getSubscribedList({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://mp.huya.com/cache/getSubscribeToInfoList?pageIndex=$page&pageSize=50',
        ),
        headers: {
          'User-Agent': _userAgent,
          'Cookie': _cookie,
          'Referer': 'https://www.huya.com/',
        },
      );

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final items = data?['vItems'] as List<dynamic>? ?? [];

      return items.map((item) {
        final d = item as Map<String, dynamic>;
        // UserSubscribeToInfo 结构:
        // lUid, lYYId, sNick, sPrivateHost, sAvatar, iRoomId,
        // iCertified, iSubscribeCount, iSubscribeTime, iIsLive
        return LiveRoom(
          roomId: '${d['iRoomId'] ?? ''}',
          title: '',
          streamerName: d['sNick'] ?? '',
          streamerAvatar: d['sAvatar'] ?? '',
          fansCount: d['iSubscribeCount'] ?? 0,
          isLive: (d['iIsLive'] ?? 0) == 1,
          coverUrl: '',
          presenterUid: d['lUid'] ?? 0,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 检查是否已订阅
  Future<bool> isSubscribed({required int presenterUid}) async {
    try {
      final response = await http.get(
        Uri.parse('https://mp.huya.com/cache/checkSubscribe?pid=$presenterUid'),
        headers: {
          'User-Agent': _userAgent,
          'Cookie': _cookie,
          'Referer': 'https://www.huya.com/',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return (json['data']?['isSubscribe'] ?? 0) == 1;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

class FollowResult {
  final bool success;
  final String message;

  FollowResult({required this.success, required this.message});
}
