import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';

class HuyaStreamResolver {
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

  Future<HuyaStreamResult?> resolveStream(String roomId) async {
    try {
      final res = await http.get(
        Uri.parse('https://m.huya.com/$roomId'),
        headers: {'User-Agent': _ua, 'Referer': 'https://m.huya.com/'},
      );
      if (res.statusCode != 200) return null;
      final m = RegExp(
        r'window\.HNF_GLOBAL_INIT\s*=\s*(\{.*?\})\s*</script>',
        dotAll: true,
      ).firstMatch(res.body);
      if (m == null) return null;
      return _parse(jsonDecode(m.group(1)!) as Map<String, dynamic>, roomId);
    } catch (_) {
      return null;
    }
  }

  /// 通过官方 profileRoom 接口补粉丝数
  Future<int> fetchFansCount(String roomId) async {
    try {
      final res = await http.get(
        Uri.parse('https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId'),
        headers: {'User-Agent': _ua},
      );
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final d = j['data'] as Map<String, dynamic>?;
      final s = (d?['streamerInfo'] as Map<String, dynamic>?) ??
          ((d?['liveData'] as Map<String, dynamic>?)?['streamerInfo'] as Map<String, dynamic>?);
      return _i(s?['lFansCount'] ?? s?['iFansCount']);
    } catch (_) {
      return 0;
    }
  }

  HuyaStreamResult? _parse(Map<String, dynamic> json, String roomId) {
    final roomInfo = json['roomInfo'] as Map<String, dynamic>?;
    final stream = json['stream'] as Map<String, dynamic>?;
    if (roomInfo == null) return null;

    final profile = (roomInfo['tProfileInfo'] as Map<String, dynamic>?) ?? {};
    final liveInfo = (roomInfo['tLiveInfo'] as Map<String, dynamic>?) ?? {};
    final data = stream?['data'] as Map<String, dynamic>?;
    final gameList = (data?['gameStreamInfoList'] as List<dynamic>?) ?? [];
    final multi = (stream?['vMultiStreamInfo'] as List<dynamic>?) ??
        ((data?['gameLiveInfo'] as Map<String, dynamic>?)?['vMultiStreamInfo'] as List<dynamic>?) ??
        [];

    final isLive = _i(liveInfo['eLiveStatus']) == 2;
    final qualities = <StreamQuality>[];

    if (gameList.isNotEmpty) {
      final base = gameList[0] as Map<String, dynamic>;
      final streamName = (base['sStreamName'] ?? '') as String;
      final sFlvUrl = (base['sFlvUrl'] ?? '') as String;
      final sHlsUrl = (base['sHlsUrl'] ?? '') as String;
      final flvSuffix = (base['sFlvUrlSuffix'] ?? 'flv') as String;
      final hlsSuffix = (base['sHlsUrlSuffix'] ?? 'm3u8') as String;
      final flvAnti = (base['sFlvAntiCode'] ?? '') as String;
      final hlsAnti = (base['sHlsAntiCode'] ?? flvAnti) as String;

      // 4 种线路：签名HLS / 签名FLV / 原始HLS / 原始FLV
      final flvP = '$sFlvUrl/$streamName.$flvSuffix?${processAnticode(flvAnti, streamName)}';
      final flvR = '$sFlvUrl/$streamName.$flvSuffix?$flvAnti';
      final hlsP = sHlsUrl.isNotEmpty
          ? '$sHlsUrl/$streamName.$hlsSuffix?${processAnticode(hlsAnti, streamName)}'
          : '';
      final hlsR = sHlsUrl.isNotEmpty ? '$sHlsUrl/$streamName.$hlsSuffix?$hlsAnti' : '';

      final rateList = multi.isNotEmpty
          ? multi
          : <dynamic>[{'sDisplayName': '原画', 'iBitRate': 0}];

      for (final r in rateList) {
        final rr = r as Map<String, dynamic>;
        final bitrate = _i(rr['iBitRate']);
        final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
        qualities.add(StreamQuality(
          name: (rr['sDisplayName'] ?? '原画') as String,
          bitrate: bitrate,
          candidates: [
            if (hlsP.isNotEmpty) '$hlsP$ratio',
            '$flvP$ratio',
            if (hlsR.isNotEmpty) '$hlsR$ratio',
            '$flvR$ratio',
          ],
        ));
      }
    }

    return HuyaStreamResult(
      roomId: roomId,
      presenterUid: _i(profile['lUid']),
      streamerInfo: StreamerInfo(
        uid: _i(profile['lUid']),
        nickname: (profile['sNick'] ?? '') as String,
        avatar: (profile['sAvatar180'] ?? '') as String,
        fansCount: _i(profile['lFansCount'] ?? profile['iFansCount']),
        isLive: isLive,
      ),
      title: (liveInfo['sIntroduction'] ?? '') as String,
      isLive: isLive,
      qualities: qualities,
    );
  }

  /// 虎牙 anti-code 签名
  static String processAnticode(String anticode, String streamName) {
    if (anticode.isEmpty) return '';
    final q = Map<String, String>.from(Uri.splitQueryString(anticode));
    String prefix = '';
    try {
      prefix = utf8
          .decode(base64.decode(Uri.decodeComponent(q['fm'] ?? '')))
          .split('_')
          .first;
    } catch (_) {}
    final u = q['u'] ?? '0';
    final wsTime = q['wsTime'] ?? '';
    final ssn = q['sStreamName'] ?? streamName;
    final ss = md5.convert(utf8.encode('$u|$streamName|$ssn')).toString();
    final wsSecret = md5.convert(utf8.encode('${prefix}_${ss}_$wsTime')).toString();
    q.remove('fm');
    q.remove('sStreamName');
    q['wsSecret'] = wsSecret;
    return q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
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
