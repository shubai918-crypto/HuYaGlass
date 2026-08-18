import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';

/// 虎牙直播流解析
/// anti-code 算法移植自 pure_live (processAnticode / getUUid)
class HuyaStreamResolver {
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';

  final Random _random = Random();

  int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
  String _s(dynamic v) => v?.toString() ?? '';

  // ================= 入口 =================
  Future<HuyaStreamResult?> resolveStream(String roomId, {int loginUid = 0}) async {
    final api = await _resolveByApi(roomId, loginUid);
    final web = await _resolveByWeb(roomId, loginUid);
    if (api == null) return web;
    if (web == null) return api;
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

  // ================= 官方 profileRoom API =================
  Future<HuyaStreamResult?> _resolveByApi(String roomId, int loginUid) async {
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
      final liveData = (data['liveData'] as Map<String, dynamic>?) ?? {};
      final stream = data['stream'] as Map<String, dynamic>?;

      final isLive = _s(data['liveStatus']) == 'ON' || _i(liveInfo['eLiveStatus']) == 2;

      final baseList = (stream?['baseSteamInfoList'] as List<dynamic>?) ??
          (stream?['gameStreamInfoList'] as List<dynamic>?) ??
          [];

      // 清晰度列表
      var rates = <dynamic>[];
      final bitRateInfo = liveData['bitRateInfo'];
      if (bitRateInfo is String && bitRateInfo.isNotEmpty) {
        try {
          rates = jsonDecode(bitRateInfo) as List<dynamic>;
        } catch (_) {}
      }
      if (rates.isEmpty) {
        rates = ((stream?['flv'] as Map<String, dynamic>?)?['rateArray'] as List<dynamic>?) ??
            (stream?['vMultiStreamInfo'] as List<dynamic>?) ??
            [];
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
        qualities: _buildQualities(baseList, rates, loginUid),
      );
    } catch (_) {
      return null;
    }
  }

  // ================= 移动端网页兜底 =================
  Future<HuyaStreamResult?> _resolveByWeb(String roomId, int loginUid) async {
    try {
      final res = await http.get(
        Uri.parse('https://m.huya.com/$roomId'),
        headers: {'User-Agent': _ua, 'Referer': 'https://m.huya.com/'},
      );
      if (res.statusCode != 200) return null;
      final body = res.body;

      // 粉丝数兜底：正则扫全页
      int webFans = 0;
      for (final key in ['lFansCount', 'lSubscribeCount', 'iSubscribeCount', 'lActivityCount', 'totalCount']) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(body);
        if (m != null) {
          webFans = int.parse(m.group(1)!);
          break;
        }
      }

      final m = RegExp(
        r'window\.HNF_GLOBAL_INIT\s*=\s*(\{.*?\})\s*</script>',
        dotAll: true,
      ).firstMatch(body);
      if (m == null) return null;
      final json = jsonDecode(m.group(1)!) as Map<String, dynamic>;

      final roomInfo = json['roomInfo'] as Map<String, dynamic>?;
      if (roomInfo == null) return null;
      final profile = (roomInfo['tProfileInfo'] as Map<String, dynamic>?) ?? {};
      final liveInfo = (roomInfo['tLiveInfo'] as Map<String, dynamic>?) ?? {};
      final streamRoot = json['stream'] as Map<String, dynamic>?;
      final streamData = (streamRoot?['data'] as Map<String, dynamic>?);

      final baseList = (streamRoot?['baseSteamInfoList'] as List<dynamic>?) ??
          (streamRoot?['gameStreamInfoList'] as List<dynamic>?) ??
          (streamData?['baseSteamInfoList'] as List<dynamic>?) ??
          (streamData?['gameStreamInfoList'] as List<dynamic>?) ??
          [];
      final rates = (streamRoot?['vMultiStreamInfo'] as List<dynamic>?) ??
          (streamData?['vMultiStreamInfo'] as List<dynamic>?) ??
          [];

      return HuyaStreamResult(
        roomId: roomId,
        presenterUid: _i(profile['lUid']),
        streamerInfo: StreamerInfo(
          uid: _i(profile['lUid']),
          nickname: _s(profile['sNick']),
          avatar: _s(profile['sAvatar180']),
          fansCount: webFans > 0
              ? webFans
              : _i(profile['lFansCount'] ?? profile['iFansCount']),
          isLive: _i(liveInfo['eLiveStatus']) == 2,
        ),
        title: _s(liveInfo['sIntroduction']),
        isLive: _i(liveInfo['eLiveStatus']) == 2,
        qualities: _buildQualities(baseList, rates, loginUid),
      );
    } catch (_) {
      return null;
    }
  }

  // ================= 组装多线路多清晰度 =================
  List<StreamQuality> _buildQualities(
    List<dynamic> baseList,
    List<dynamic> rates,
    int loginUid,
  ) {
    final qualities = <StreamQuality>[];
    if (baseList.isEmpty) return qualities;

    // 最多取 3 条 CDN 线路做备份
    final lines = baseList.take(3).toList();
    final rateList = rates.isNotEmpty
        ? rates
        : <dynamic>[{'sDisplayName': '原画', 'iBitRate': 0}];

    for (final r in rateList) {
      final rr = r as Map<String, dynamic>;
      final bitrate = _i(rr['iBitRate']);
      final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
      final candidates = <String>[];

      for (final b in lines) {
        final bm = b as Map<String, dynamic>;
        final streamName = _s(bm['sStreamName']);
        if (streamName.isEmpty) continue;
        final sFlvUrl = _s(bm['sFlvUrl']).trim();
        final sHlsUrl = _s(bm['sHlsUrl']).trim();
        final flvSuffix = _s(bm['sFlvUrlSuffix']).isEmpty ? 'flv' : _s(bm['sFlvUrlSuffix']);
        final hlsSuffix = _s(bm['sHlsUrlSuffix']).isEmpty ? 'm3u8' : _s(bm['sHlsUrlSuffix']);
        final uid = _uidFor(loginUid, streamName);

        void addBoth(String url) {
          // https 优先，http 兜底
          if (url.startsWith('http://')) {
            candidates.add(url.replaceFirst('http://', 'https://'));
          }
          candidates.add(url);
        }

        if (sFlvUrl.isNotEmpty) {
          final anti = processAnticode(_s(bm['sFlvAntiCode']), streamName, uid);
          addBoth('$sFlvUrl/$streamName.$flvSuffix?$anti&codec=264$ratio');
        }
        if (sHlsUrl.isNotEmpty) {
          final anti = processAnticode(_s(bm['sHlsAntiCode']), streamName, uid);
          addBoth('$sHlsUrl/$streamName.$hlsSuffix?$anti$ratio');
        }
      }

      if (candidates.isNotEmpty) {
        final name = _s(rr['sDisplayName']).isEmpty
            ? (bitrate == 0 ? '原画' : '蓝光${bitrate ~/ 1000}M')
            : _s(rr['sDisplayName']);
        qualities.add(StreamQuality(
          name: name,
          bitrate: bitrate,
          candidates: candidates,
        ));
      }
    }
    return qualities;
  }

  // ================= pure_live 同款 anti-code 算法 =================
  static String processAnticode(String anticode, String streamName, int uid) {
    if (anticode.isEmpty) return '';
    final query = Map<String, String>.from(Uri.splitQueryString(anticode));

    // 固定参数（pure_live 关键步骤）
    query['ctype'] = 'huya_live';
    query['t'] = '100';

    // 解码 fm 取哈希前缀
    String hash = '';
    try {
      final fmDecoded = utf8.decode(base64.decode(Uri.decodeComponent(query['fm'] ?? '')));
      hash = fmDecoded.split('_').first;
    } catch (_) {}

    final sStreamName = query['sStreamName'] ?? streamName;
    final wsTime = query['wsTime'] ?? '';

    // ss = md5("{uid}|{streamName}|{sStreamName}")
    final ss = md5.convert(utf8.encode('$uid|$streamName|$sStreamName')).toString();
    // wsSecret = md5("{hash}_{ss}_{wsTime}")
    query['wsSecret'] = md5.convert(utf8.encode('${hash}_${ss}_$wsTime')).toString();

    query.remove('fm');
    query.remove('sStreamName');

    return query.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  // ================= uid 取值（pure_live getUUid 同款） =================
  int _uidFor(int loginUid, String streamName) {
    if (loginUid > 0) return loginUid;
    final parts = streamName.split('-');
    if (parts.isNotEmpty) {
      final anchorUid = int.tryParse(parts[0]);
      if (anchorUid != null && anchorUid > 0) return anchorUid;
    }
    return 1400000000000 + _random.nextInt(100000000000);
  }

  // ================= 粉丝数 =================
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
      return _i(p?['lFansCount'] ?? p?['iFansCount'] ?? p?['lSubscribeCount']);
    } catch (_) {
      return 0;
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
