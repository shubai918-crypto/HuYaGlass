import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';

class HuyaStreamResolver {
  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  /// 解析虎牙直播间流地址
  Future<HuyaStreamInfo?> resolveStream(String roomId) async {
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

      return _parseStreamInfo(json);
    } catch (e) {
      return null;
    }
  }

  HuyaStreamInfo? _parseStreamInfo(Map<String, dynamic> json) {
    try {
      final roomInfo = json['roomInfo'] as Map<String, dynamic>?;
      final streamInfo = json['stream'] as Map<String, dynamic>?;

      if (roomInfo == null || streamInfo == null) return null;

      final presenterUid = roomInfo['tProfileInfo']?['lUid'] ?? 0;
      final presenterName = roomInfo['tProfileInfo']?['sNick'] ?? '';
      final fansCount = roomInfo['tProfileInfo']?['lFansCount'] ?? 0;
      final title = roomInfo['tLiveInfo']?['sIntroduction'] ?? '';
      final isLive = roomInfo['tLiveInfo']?['eLiveStatus'] == 2;

      // 解析流地址列表
      final qualities = <StreamQuality>[];
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
          ));
        }
      }

      // 如果没有 vMultiStreamInfo，尝试从默认流获取
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

      return HuyaStreamInfo(
        roomId: roomId,
        presenterUid: presenterUid,
        presenterName: presenterName,
        fansCount: fansCount,
        title: title,
        isLive: isLive,
        qualities: qualities,
      );
    } catch (e) {
      return null;
    }
  }
}

class HuyaStreamInfo {
  final String roomId;
  final int presenterUid;
  final String presenterName;
  final int fansCount;
  final String title;
  final bool isLive;
  final List<StreamQuality> qualities;

  HuyaStreamInfo({
    required this.roomId,
    required this.presenterUid,
    required this.presenterName,
    required this.fansCount,
    required this.title,
    required this.isLive,
    required this.qualities,
  });
}
