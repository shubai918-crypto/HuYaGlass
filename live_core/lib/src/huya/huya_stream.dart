import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';

/// 虎牙直播流解析：官方 profileRoom API 优先，移动端网页兜底
class HuyaStreamResolver {
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
  String _s(dynamic v) => v?.toString() ?? '';

  Future<HuyaStreamResult?> resolveStream(String roomId) async {
    // 1. 官方 API（dtv_mobile / pure_live 同款）
    var result = await _resolveByApi(roomId);
    // 2. 网页兜底
    if (result == null || result.qualities.isEmpty) {
      final web = await _resolveByWeb(roomId);
      if (web != null && web.qualities.isNotEmpty) result = web;
    }
    return result;
  }

  // ================= 官方 profileRoom API =================
  Future<HuyaStreamResult?> _resolveByApi(String roomId) async {
    try {
      final res = await http.get(
        Uri.parse('https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId'),
        headers: {'User-Agent': _ua, 'Referer': 'https://www.huya.com/'},
      );
      if (res.statusCode != 200) return null;
      final root = jsonDecode(res.body) as Map<String, dynamic>;
      if (_i(root['status']) != 200) return null;
      final data = root['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final profile = (data['profileInfo'] as Map<String, dynamic>?) ??
          (data['streamerInfo'] as Map<String, dynamic>?) ??
          {};
      final liveInfo = (data['liveInfo'] as Map<String, dynamic>?) ?? {};
      final stream = data['stream'] as Map<String, dynamic>?;

      final isLive = _s(data['liveStatus']) == 'ON' || _i(liveInfo['eLiveStatus']) == 2;

      final baseList = (stream?['baseSteamInfoList'] as List<dynamic>?) ??
          (stream?['gameStreamInfoList'] as List<dynamic>?) ??
          [];
      final multi = (stream?['vMultiStreamInfo'] as List<dynamic>?) ?? [];

      final qualities = <StreamQuality>[];
      if (baseList.isNotEmpty) {
        qualities.addAll(_buildQualities(baseList[0] as Map<String, dynamic>, multi));
      }

      return HuyaStreamResult(
        roomId: roomId,
        presenterUid: _i(profile['yyid'] ?? profile['lUid'] ?? profile['lPresenterUid']),
        streamerInfo: StreamerInfo(
          uid: _i(profile['yyid'] ?? profile['lUid']),
          nickname: _s(profile['sNick'] ?? profile['sPresenterNick']),
          avatar: _s(profile['sAvatar180'] ?? profile['sAvatar']),
          fansCount: _i(profile['lFansCount'] ?? profile['iFansCount'] ?? liveInfo['lFansCount']),
          isLive: isLive,
        ),
        title: _s(liveInfo['sIntroduction'] ?? liveInfo['sRoomName']),
        isLive: isLive,
        qualities: qualities,
      );
    } catch (_) {
      return null;
    }
  }

  // ================= 移动端网页兜底 =================
  Future<HuyaStreamResult?> resolveStream(String roomId) async {
    final api = await _resolveByApi(roomId);
    final web = await _resolveByWeb(roomId);

    if (api == null) return web;
    if (web == null) return api;

    // 合并：线路优先用 API 的，主播信息用网页补全
    return HuyaStreamResult(
      roomId: roomId,
      presenterUid: api.presenterUid != 0 ? api.presenterUid : web.presenterUid,
      streamerInfo: StreamerInfo(
        uid: api.presenterUid != 0 ? api.presenterUid : web.presenterUid,
        nickname: api.streamerInfo.nickname.isNotEmpty
            ? api.streamerInfo.nickname
            : web.streamerInfo.nickname,
        avatar: api.streamerInfo.avatar.isNotEmpty
            ? api.streamerInfo.avatar
            : web.streamerInfo.avatar,
        fansCount: api.streamerInfo.fansCount > 0
            ? api.streamerInfo.fansCount
            : web.streamerInfo.fansCount,
        isLive: api.isLive || web.isLive,
      ),
      title: api.title.isNotEmpty ? api.title : web.title,
      isLive: api.isLive || web.isLive,
      qualities: api.qualities.isNotEmpty ? api.qualities : web.qualities,
    );
  }

  // ================= 组装多线路 =================
  List<StreamQuality> _buildQualities(Map<String, dynamic> base, List<dynamic> multi) {
    final streamName = _s(base['sStreamName']);
    final sFlvUrl = _s(base['sFlvUrl']);
    final sHlsUrl = _s(base['sHlsUrl']);
    final flvSuffix = _s(base['sFlvUrlSuffix']).isEmpty ? 'flv' : _s(base['sFlvUrlSuffix']);
    final hlsSuffix = _s(base['sHlsUrlSuffix']).isEmpty ? 'm3u8' : _s(base['sHlsUrlSuffix']);
    final flvAnti = _s(base['sFlvAntiCode']);
    final hlsAnti = _s(base['sHlsAntiCode']).isEmpty ? flvAnti : _s(base['sHlsAntiCode']);
    if (streamName.isEmpty || sFlvUrl.isEmpty) return [];

    final flvP = '$sFlvUrl/$streamName.$flvSuffix?${processAnticode(flvAnti, streamName)}';
    final flvR = '$sFlvUrl/$streamName.$flvSuffix?$flvAnti';
    final hlsP = sHlsUrl.isNotEmpty
        ? '$sHlsUrl/$streamName.$hlsSuffix?${processAnticode(hlsAnti, streamName)}'
        : '';
    final hlsR = sHlsUrl.isNotEmpty ? '$sHlsUrl/$streamName.$hlsSuffix?$hlsAnti' : '';

    final rateList = multi.isNotEmpty
        ? multi
        : <dynamic>[{'sDisplayName': '原画', 'iBitRate': 0}];

    final result = <StreamQuality>[];
    for (final r in rateList) {
      final rr = r as Map<String, dynamic>;
      final bitrate = _i(rr['iBitRate']);
      final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
      final name = _s(rr['sDisplayName']).isEmpty
          ? (bitrate == 0 ? '原画' : '蓝光${bitrate ~/ 1000}M')
          : _s(rr['sDisplayName']);
      result.add(StreamQuality(
        name: name,
        bitrate: bitrate,
        candidates: [
          if (hlsP.isNotEmpty) '$hlsP$ratio',
          '$flvP$ratio',
          if (hlsR.isNotEmpty) '$hlsR$ratio',
          '$flvR$ratio',
        ],
      ));
    }
    return result;
  }

  /// 粉丝数（profileRoom 接口）
  Future<int> fetchFansCount(String roomId) async {
    try {
      final res = await http.get(
        Uri.parse('https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId'),
        headers: {'User-Agent': _ua},
      );
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final d = j['data'] as Map<String, dynamic>?;
      final p = (d?['profileInfo'] as Map<String, dynamic>?) ??
          (d?['streamerInfo'] as Map<String, dynamic>?);
      return _i(p?['lFansCount'] ?? p?['iFansCount']);
    } catch (_) {
      return 0;
    }
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
