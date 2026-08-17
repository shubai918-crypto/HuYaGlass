import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';

/// 虎牙直播流地址解析（参考 pure_live / dart_simple_live）
class HuyaStreamResolver {
  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  /// 解析直播间流地址和画质列表
  Future<HuyaStreamResult?> resolveStream(String roomId) async {
    try {
      final url = 'https://m.huya.com/$roomId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Referer': 'https://m.huya.com/',
        },
      );

      if (response.statusCode != 200) return null;
      final html = response.body;

      // 提取 window.HNF_GLOBAL_INIT 数据
      final regex = RegExp(
        r'window\.HNF_GLOBAL_INIT\s*=\s*(\{.*?\})\s*</script>',
        dotAll: true,
      );
      final match = regex.firstMatch(html);
      if (match == null) return null;

      final jsonStr = match.group(1)!;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _parseStreamInfo(json, roomId);
    } catch (e) {
      return null;
    }
  }

  HuyaStreamResult? _parseStreamInfo(Map<String, dynamic> json, String roomId) {
    try {
      final roomInfo = json['roomInfo'] as Map<String, dynamic>?;
      final streamInfo = json['stream'] as Map<String, dynamic>?;

      if (roomInfo == null) return null;

      // 主播信息
      final profile = roomInfo['tProfileInfo'] as Map<String, dynamic>? ?? {};
      final liveInfo = roomInfo['tLiveInfo'] as Map<String, dynamic>? ?? {};

      final presenterUid = profile['lUid'] ?? 0;
      final presenterName = profile['sNick'] ?? '';
      final fansCount = profile['lFansCount'] ?? 0;
      final avatar = profile['sAvatar180'] ?? '';
      final title = liveInfo['sIntroduction'] ?? '';
      final isLive = (liveInfo['eLiveStatus'] ?? 0) == 2;

      // 解析流地址列表
      final qualities = <StreamQuality>[];
      if (streamInfo != null) {
        final streamList = streamInfo['vMultiStreamInfo'] as List<dynamic>? ?? [];
        for (var item in streamList) {
          final stream = item as Map<String, dynamic>;
          final name = stream['sDisplayName'] ?? '';
          final bitrate = stream['iBitRate'] ?? 0;
          final sFlvUrl = stream['sFlvUrl'] ?? '';
          final suffix = stream['sFlvUrlSuffix'] ?? '';
          final antiCode = stream['sFlvAntiCode'] ?? '';

          if (sFlvUrl.isNotEmpty) {
            final fullUrl = '$sFlvUrl.$suffix?$antiCode';
            qualities.add(StreamQuality(
              name: name,
              bitrate: bitrate,
              flvUrl: fullUrl,
              suffix: suffix,
              antiCode: antiCode,
            ));
          }
        }

        // 如果没有 vMultiStreamInfo，尝试默认流
        if (qualities.isEmpty) {
          final defaultFlv = streamInfo['sFlvUrl'] as String? ?? '';
          if (defaultFlv.isNotEmpty) {
            qualities.add(StreamQuality(
              name: '原画',
              bitrate: 0,
              flvUrl: defaultFlv,
            ));
          }
        }
      }

      return HuyaStreamResult(
        roomId: roomId,
        presenterUid: presenterUid,
        streamerInfo: StreamerInfo(
          uid: presenterUid,
          nickname: presenterName,
          avatar: avatar,
          fansCount: fansCount,
          isLive: isLive,
        ),
        title: title,
        isLive: isLive,
        qualities: qualities,
      );
    } catch (e) {
      return null;
    }
  }
}

class HuyaStreamResult {
  final String roomId;
  final int presenterUid;
  final StreamerInfo streamerInfo;
  final String title;
  final bool isLive;
  final List<StreamQuality> qualities;

  HuyaStreamResult({
    required this.roomId,
    required this.presenterUid,
    required this.streamerInfo,
    required this.title,
    required this.isLive,
    required this.qualities,
  });
}
