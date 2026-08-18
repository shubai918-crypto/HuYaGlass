import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';

/// 虎牙直播流解析
/// 线路组装对齐 pure_live：multiLine + anti-code 重签名 + codec=264
class HuyaStreamResolver {
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';

  static final Random _random = Random();

  int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
  String _s(dynamic v) => v?.toString() ?? '';

  // ================= 入口：API 优先，网页兜底，信息合并 =================
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
      final stream = (data['stream'] as Map<String, dynamic>?) ?? {};

      final isLive = _s(data['liveStatus']) == 'ON' || _i(liveInfo['eLiveStatus']) == 2;

      final baseList = (stream['baseSteamInfoList'] as List<dynamic>?) ??
          (stream['gameStreamInfoList'] as List<dynamic>?) ??
          [];
      final flvLines = (stream['flv'] as Map<String, dynamic>?)?['multiLine'] as List<dynamic>?;
      final hlsLines = (stream['hls'] as Map<String, dynamic>?)?['multiLine'] as List<dynamic>?;

      var rates = <dynamic>[];
      final bitRateInfo = liveData['bitRateInfo'];
      if (bitRateInfo is String && bitRateInfo.isNotEmpty) {
        try {
          rates = jsonDecode(bitRateInfo) as List<dynamic>;
        } catch (_) {}
      }
      if (rates.isEmpty) {
        rates = ((stream['flv'] as Map<String, dynamic>?)?['rateArray'] as List<dynamic>?) ??
            (stream['vMultiStreamInfo'] as List<dynamic>?) ??
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
        qualities: _buildQualities(
          baseList: baseList,
          flvLines: flvLines,
          hlsLines: hlsLines,
          rates: rates,
          loginUid: loginUid,
        ),
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
      final streamRoot = (json['stream'] as Map<String, dynamic>?) ?? {};
      final streamData = (streamRoot['data'] as Map<String, dynamic>?);

      final baseList = (streamRoot['baseSteamInfoList'] as List<dynamic>?) ??
          (streamRoot['gameStreamInfoList'] as List<dynamic>?) ??
          (streamData?['baseSteamInfoList'] as List<dynamic>?) ??
          (streamData?['gameStreamInfoList'] as List<dynamic>?) ??
          [];
      final rates = (streamRoot['vMultiStreamInfo'] as List<dynamic>?) ??
          (streamData?['vMultiStreamInfo'] as List<dynamic>?) ??
          [];

      return HuyaStreamResult(
        roomId: roomId,
        presenterUid: _i(profile['lUid']),
        streamerInfo: StreamerInfo(
          uid: _i(profile['lUid']),
          nickname: _s(profile['sNick']),
          avatar: _s(profile['sAvatar180']),
          fansCount: webFans > 0 ? webFans : _i(profile['lFansCount'] ?? profile['iFansCount']),
          isLive: _i(liveInfo['eLiveStatus']) == 2,
        ),
        title: _s(liveInfo['sIntroduction']),
        isLive: _i(liveInfo['eLiveStatus']) == 2,
        qualities: _buildQualities(
          baseList: baseList,
          flvLines: null,
          hlsLines: null,
          rates: rates,
          loginUid: loginUid,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ================= 线路组装（multiLine 按 cdnType 匹配 baseSteamInfoList） =================
  List<StreamQuality> _buildQualities({
    required List<dynamic> baseList,
    List<dynamic>? flvLines,
    List<dynamic>? hlsLines,
    required List<dynamic> rates,
    required int loginUid,
  }) {
    final qualities = <StreamQuality>[];
    if (baseList.isEmpty) return qualities;

    final rateList = rates.isNotEmpty
        ? rates
        : <dynamic>[{'sDisplayName': '原画', 'iBitRate': 0}];

    Map<String, dynamic> baseForCdn(String cdn) {
      for (final e in baseList) {
        final em = e as Map<String, dynamic>;
        if (_s(em['sCdnType']) == cdn) return em;
      }
      return baseList.first as Map<String, dynamic>;
    }

    // 关键：multiLine 的 url 可能已是"带路径+旧签名"的完整地址，
    // 必须 Uri.parse 拆开复用路径与参数，只重算 wsSecret，不能再拼一层
    String composeUrl(
      String lineUrl,
      Map<String, dynamic> base,
      String suffix,
      String fallbackAnti,
      String ratio, {
      String extra = '',
    }) {
      final streamName = _s(base['sStreamName']);
      if (streamName.isEmpty || lineUrl.isEmpty) return '';
      try {
        final u = Uri.parse(lineUrl);
        String path = u.path;
        final file = '$streamName.$suffix';
        if (!path.endsWith(file)) {
          if (!path.endsWith('/')) path += '/';
          path += file;
        }
        final antiSource = u.query.isNotEmpty ? u.query : fallbackAnti;
        final processed = processAnticode(antiSource, streamName, loginUid);
        if (processed.isEmpty) return '';
        return '${u.scheme}://${u.authority}$path?$processed$ratio$extra';
      } catch (_) {
        return '';
      }
    }

    for (final r in rateList) {
      final rr = r as Map<String, dynamic>;
      final bitrate = _i(rr['iBitRate']);
      final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
      final urls = <String>[];

      // FLV 线路（pure_live 同款，追加 codec=264 请求 H.264）
      if (flvLines != null && flvLines.isNotEmpty) {
        for (final l in flvLines) {
          final lm = l as Map<String, dynamic>;
          final base = baseForCdn(_s(lm['cdnType']));
          final suffix = _s(base['sFlvUrlSuffix']).isEmpty ? 'flv' : _s(base['sFlvUrlSuffix']);
          final url = composeUrl(
            _s(lm['url']).trim(),
            base,
            suffix,
            _s(base['sFlvAntiCode']),
            ratio,
            extra: '&codec=264',
          );
          if (url.isNotEmpty) urls.add(url);
        }
      }

      // HLS 线路
      if (hlsLines != null && hlsLines.isNotEmpty) {
        for (final l in hlsLines) {
          final lm = l as Map<String, dynamic>;
          final base = baseForCdn(_s(lm['cdnType']));
          final suffix = _s(base['sHlsUrlSuffix']).isEmpty ? 'm3u8' : _s(base['sHlsUrlSuffix']);
          final url = composeUrl(_s(lm['url']).trim(), base, suffix, _s(base['sHlsAntiCode']), ratio);
          if (url.isNotEmpty) urls.add(url);
        }
      }

      // 兜底：没有 multiLine 时用 baseSteamInfoList 自带地址
      if (urls.isEmpty) {
        for (final b in baseList) {
          final bm = b as Map<String, dynamic>;
          final sFlvUrl = _s(bm['sFlvUrl']).trim();
          final sHlsUrl = _s(bm['sHlsUrl']).trim();
          if (sFlvUrl.isNotEmpty) {
            final suffix = _s(bm['sFlvUrlSuffix']).isEmpty ? 'flv' : _s(bm['sFlvUrlSuffix']);
            final url = composeUrl(sFlvUrl, bm, suffix, _s(bm['sFlvAntiCode']), ratio, extra: '&codec=264');
            if (url.isNotEmpty) urls.add(url);
          }
          if (sHlsUrl.isNotEmpty) {
            final suffix = _s(bm['sHlsUrlSuffix']).isEmpty ? 'm3u8' : _s(bm['sHlsUrlSuffix']);
            final url = composeUrl(sHlsUrl, bm, suffix, _s(bm['sHlsAntiCode']), ratio);
            if (url.isNotEmpty) urls.add(url);
          }
        }
      }

      if (urls.isNotEmpty) {
        final name = _s(rr['sDisplayName']).isEmpty
            ? (bitrate == 0 ? '原画' : '蓝光${bitrate ~/ 1000}M')
            : _s(rr['sDisplayName']);
        qualities.add(StreamQuality(name: name, bitrate: bitrate, candidates: urls));
      }
    }
    return qualities;
  }

  // ============ anti-code：原样保留服务器参数，只重算 wsSecret（pure_live 同款） ============
  static String processAnticode(String anticode, String streamName, int loginUid) {
    if (anticode.isEmpty) return '';
    final parts = anticode.split('&');
    String fmRaw = '';
    String wsTime = '';
    final kept = <String>[];
    for (final p in parts) {
      final i = p.indexOf('=');
      final k = i < 0 ? p : p.substring(0, i);
      final v = i < 0 ? '' : p.substring(i + 1);
      if (k == 'fm') {
        fmRaw = v;
        continue;
      }
      if (k == 'wsSecret' || k == 'sStreamName') continue;
      if (k == 'wsTime') wsTime = Uri.decodeComponent(v);
      kept.add(p); // 原样保留，不重新编码
    }

    String hash = '';
    try {
      hash = utf8.decode(base64.decode(Uri.decodeComponent(fmRaw))).split('_').first;
    } catch (_) {}

    final uid = _uidFor(loginUid, streamName);
    final ss = md5.convert(utf8.encode('$uid|$streamName|$streamName')).toString();
    final wsSecret = md5.convert(utf8.encode('${hash}_${ss}_$wsTime')).toString();

    kept.add('wsSecret=$wsSecret');
    if (!kept.any((p) => p.startsWith('ctype='))) kept.add('ctype=huya_live');
    if (!kept.any((p) => p.startsWith('t='))) kept.add('t=100');
    return kept.join('&');
  }

  // ============ uid 取值（pure_live getUUid 同款） ============
  static int _uidFor(int loginUid, String streamName) {
    if (loginUid > 0) return loginUid;
    final parts = streamName.split('-');
    if (parts.isNotEmpty) {
      final anchorUid = int.tryParse(parts[0]);
      if (anchorUid != null && anchorUid > 0) return anchorUid;
    }
    return 1400000000000 + _random.nextInt(100000000000);
  }

  // ============ 粉丝数 ============
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
