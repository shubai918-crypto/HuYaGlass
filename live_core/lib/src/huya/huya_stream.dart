import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';

/// 虎牙直播流解析（参考 pure_live / dart_simple_live）
class HuyaStreamResolver {
  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  Future<HuyaStreamResult?> resolveStream(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse('https://m.huya.com/$roomId'),
        headers: {'User-Agent': _userAgent, 'Referer': 'https://m.huya.com/'},
      );
      if (response.statusCode != 200) return null;

      final match = RegExp(
        r'window\.HNF_GLOBAL_INIT\s*=\s*(\{.*?\})\s*</script>',
        dotAll: true,
      ).firstMatch(response.body);
      if (match == null) return null;

      final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
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

      final profile = roomInfo['tProfileInfo'] as Map<String, dynamic>? ?? {};
      final liveInfo = roomInfo['tLiveInfo'] as Map<String, dynamic>? ?? {};

      final presenterUid = (profile['lUid'] ?? 0) as int;
      final presenterName = profile['sNick'] ?? '';
      final fansCount = (profile['lFansCount'] ?? profile['iFansCount'] ?? 0) as int;
      final avatar = profile['sAvatar180'] ?? '';
      final title = liveInfo['sIntroduction'] ?? '';
      final isLive = (liveInfo['eLiveStatus'] ?? 0) == 2;

      final qualities = <StreamQuality>[];
      final baseInfo = streamInfo?['data']?['gameStreamInfoList'] as List<dynamic>? ??
          streamInfo?['vMultiStreamInfo'] as List<dynamic>? ??
          [];

      // 先取 gameStreamInfoList（含流名），再退而求其次
      final streamList = (streamInfo?['data']?['gameStreamInfoList'] as List<dynamic>?) ??
          (streamInfo?['vMultiStreamInfo'] as List<dynamic>?) ??
          [];
      final rateList = (streamInfo?['data']?['gameLiveInfo']?['vMultiStreamInfo'] as List<dynamic>?) ?? [];

      for (var item in streamList) {
        final s = item as Map<String, dynamic>;
        final streamName = (s['sStreamName'] ?? '') as String;
        final sFlvUrl = (s['sFlvUrl'] ?? '') as String;
        final sHlsUrl = (s['sHlsUrl'] ?? '') as String;
        final flvSuffix = (s['sFlvUrlSuffix'] ?? 'flv') as String;
        final hlsSuffix = (s['sHlsUrlSuffix'] ?? 'm3u8') as String;
        final flvAnti = (s['sFlvAntiCode'] ?? '') as String;
        final hlsAnti = (s['sHlsAntiCode'] ?? flvAnti) as String;

        if (streamName.isEmpty || sFlvUrl.isEmpty) continue;

        qualities.add(StreamQuality(
          name: (s['sDisplayName'] ?? '原画') as String,
          bitrate: (s['iBitRate'] ?? 0) as int,
          flvUrl: '$sFlvUrl/$streamName.$flvSuffix?${processAnticode(flvAnti, streamName)}',
          hlsUrl: sHlsUrl.isNotEmpty
              ? '$sHlsUrl/$streamName.$hlsSuffix?${processAnticode(hlsAnti, streamName)}'
              : '',
        ));
      }

      // 如果 gameStreamInfoList 为空，用 vMultiStreamInfo 的清晰度名 + 默认流
      if (qualities.isEmpty && streamInfo != null) {
        final sFlvUrl = (streamInfo['sFlvUrl'] ?? '') as String;
        final streamName = (streamInfo['sStreamName'] ?? '') as String;
        if (sFlvUrl.isNotEmpty && streamName.isNotEmpty) {
          final anti = (streamInfo['sFlvAntiCode'] ?? '') as String;
          final suffix = (streamInfo['sFlvUrlSuffix'] ?? 'flv') as String;
          for (var r in rateList) {
            final rr = r as Map<String, dynamic>;
            qualities.add(StreamQuality(
              name: (rr['sDisplayName'] ?? '原画') as String,
              bitrate: (rr['iBitRate'] ?? 0) as int,
              flvUrl: '$sFlvUrl/$streamName.$suffix?${processAnticode(anti, streamName)}',
            ));
          }
          if (qualities.isEmpty) {
            qualities.add(StreamQuality(
              name: '原画',
              bitrate: 0,
              flvUrl: '$sFlvUrl/$streamName.$suffix?${processAnticode(anti, streamName)}',
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

  /// 虎牙 anti-code 签名（参考 pure_live / dart_simple_live 的通用算法）
  static String processAnticode(String anticode, String streamName) {
    if (anticode.isEmpty) return '';
    final query = Map<String, String>.from(Uri.splitQueryString(anticode));

    String prefix = '';
    try {
      final fmDecoded = utf8.decode(base64.decode(Uri.decodeComponent(query['fm'] ?? '')));
      prefix = fmDecoded.split('_').first;
    } catch (_) {}

    final u = query['u'] ?? '0';
    final wsTime = query['wsTime'] ?? '';
    final sStreamName = query['sStreamName'] ?? streamName;

    final ss = md5.convert(utf8.encode('$u|$streamName|$sStreamName')).toString();
    final wsSecret = md5.convert(utf8.encode('${prefix}_${ss}_$wsTime')).toString();

    query.remove('fm');
    query.remove('sStreamName');
    query['wsSecret'] = wsSecret;

    return query.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
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
