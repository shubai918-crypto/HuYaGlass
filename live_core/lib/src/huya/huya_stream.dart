import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';
import 'huya_login.dart';

class HuyaStreamResolver {
  static const _iosMobileUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  static const _huyaWebh5Cookie = 'huya_ua=webh5&0.1.0&websocket';
  static const _sdkVersion = '2403051612';

  final Random _random = Random();

  int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
  String _s(dynamic v) => v?.toString() ?? '';

  int _firstNonZero(List<dynamic> vals) {
    for (final v in vals) {
      final n = _i(v);
      if (n > 0) return n;
    }
    return 0;
  }

  String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  static String enforceHttp(String url) => url.startsWith('https://')
      ? url.replaceFirst('https://', 'http://')
      : url;

  Map<String, String> _parseQuery(String qs) {
    var trimmed = qs.trim();
    while (trimmed.startsWith('?') || trimmed.startsWith('&')) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.isEmpty) return {};
    final map = <String, String>{};
    for (final kv in trimmed.split('&')) {
      final idx = kv.indexOf('=');
      if (idx <= 0) continue;
      map[kv.substring(0, idx)] = kv.substring(idx + 1);
    }
    return map;
  }

  String _urlDecodeOnce(String s) {
    try { return Uri.decodeComponent(s); } catch (_) { return s; }
  }

  String _cdnOf(String key) {
    final i = key.indexOf(':');
    return i >= 0 ? key.substring(i + 1) : key;
  }

  String generateWebAntiCode(String streamName, String antiCode) {
    try {
      final sanitized = antiCode.replaceAll('&amp;', '&');
      final params = _parseQuery(sanitized);
      final fmValue = params['fm'];
      final ctype = params['ctype'];
      final fs = params['fs'];
      if (fmValue == null || ctype == null || fs == null) return '';

      final fmDecoded = _urlDecodeOnce(fmValue);
      final fmPlain = utf8.decode(base64.decode(fmDecoded));
      final wsPrefix = fmPlain.split('_').first;
      if (wsPrefix.isEmpty) return '';

      const paramsT = 100;
      final t13 = DateTime.now().millisecondsSinceEpoch;
      final sdkSid = t13;
      final uid = 1400000000000 + (_random.nextDouble() * 10000000000).floor();
      final seqId = uid + sdkSid;
      final wsTime = ((t13 + 110624) ~/ 1000).toRadixString(16);
      final uuidSeed = (t13 % 10000000000) * 1000 + (_random.nextDouble() * 1000).floor();
      final initUuid = uuidSeed % 4294967295;

      final wsSecretHash = _md5('$seqId|$ctype|$paramsT');
      final wsSecretPlain = '${wsPrefix}_${uid}_${streamName}_${wsSecretHash}_$wsTime';
      final wsSecretMd5 = _md5(wsSecretPlain);

      final parts = [
        'wsSecret=$wsSecretMd5', 'wsTime=$wsTime', 'seqid=$seqId',
        'ctype=$ctype', 'ver=1', 'fs=$fs', 'uuid=$initUuid',
        'u=$uid', 't=$paramsT', 'sv=$_sdkVersion', 'sdk_sid=$sdkSid', 'codec=264',
      ];
      return parts.join('&');
    } catch (_) { return ''; }
  }

  String _adjustTxStreamUrl(String url, String cdn) {
    if (cdn.toLowerCase() != 'tx') return enforceHttp(url);
    var s = url.replaceAll('&ctype=tars_mp', '&ctype=huya_webh5');
    s = s.replaceAll('&fs=bhct', '&fs=bgct');
    return enforceHttp(s);
  }

  String _trimSlash(String u) {
    var s = u.trim();
    while (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  Future<String> _fetchHtml(String roomId, bool mobile) async {
    final loginCookie = HuyaLoginManager().cookie;
    final res = await http.get(
      Uri.parse('https://www.huya.com/$roomId'),
      headers: {
        'User-Agent': mobile ? _iosMobileUa : _desktopUa,
        'Referer': mobile ? 'https://m.huya.com/' : 'https://www.huya.com/',
        'Cookie': loginCookie.isNotEmpty ? loginCookie : _huyaWebh5Cookie,
      },
    );
    return res.statusCode == 200 ? res.body : '';
  }

  Map<String, dynamic>? _parseStreamBlock(String html) {
    try {
      final re = RegExp(r'stream:\s*(\{"data".*?),"iWebDefaultBitRate"', dotAll: true);
      final m = re.firstMatch(html);
      if (m == null) return null;
      return jsonDecode('${m.group(1)}}') as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  // ★ 核心：HLS 优先，FLV 兜底
  List<MapEntry<String, String>> _parseCandidates(Map<String, dynamic>? block) {
    final result = <MapEntry<String, String>>[];
    if (block == null) return result;
    try {
      final dataList = block['data'] as List<dynamic>?;
      final first = (dataList != null && dataList.isNotEmpty) ? dataList.first as Map<String, dynamic> : null;
      final streamInfoList = first?['gameStreamInfoList'] as List<dynamic>?;
      if (streamInfoList == null) return result;
      
      for (final item in streamInfoList) {
        final obj = item as Map<String, dynamic>;
        final cdn = _s(obj['sCdnType']);
        final streamName = _s(obj['sStreamName']);
        if (cdn.isEmpty || streamName.isEmpty) continue;

        // 1. 先加 HLS (ExoPlayer 完美支持)
        final hlsUrl = _trimSlash(_s(obj['sHlsUrl']));
        final hlsSuffix = _s(obj['sHlsUrlSuffix']).isEmpty ? 'm3u8' : _s(obj['sHlsUrlSuffix']);
        final hlsAnti = _s(obj['sHlsAntiCode']);
        if (hlsUrl.isNotEmpty && hlsAnti.isNotEmpty) {
          final antiParams = generateWebAntiCode(streamName, hlsAnti);
          if (antiParams.isNotEmpty) {
            result.add(MapEntry('hls:$cdn', enforceHttp('$hlsUrl/$streamName.$hlsSuffix?$antiParams')));
          }
        }

        // 2. 再加 FLV (兜底)
        final flvUrl = _trimSlash(_s(obj['sFlvUrl']));
        final flvSuffix = _s(obj['sFlvUrlSuffix']).isEmpty ? 'flv' : _s(obj['sFlvUrlSuffix']);
        final flvAnti = _s(obj['sFlvAntiCode']);
        if (flvUrl.isNotEmpty && flvAnti.isNotEmpty) {
          final antiParams = generateWebAntiCode(streamName, flvAnti);
          if (antiParams.isNotEmpty) {
            result.add(MapEntry('flv:$cdn', enforceHttp('$flvUrl/$streamName.$flvSuffix?$antiParams')));
          }
        }
      }
    } catch (_) {}
    return result;
  }

  List<dynamic> _parseRates(Map<String, dynamic>? block) {
    if (block == null) return [];
    var rates = block['vMultiStreamInfo'] as List<dynamic>?;
    if (rates == null || rates.isEmpty) {
      final dataList = block['data'] as List<dynamic>?;
      final first = (dataList != null && dataList.isNotEmpty) ? dataList.first as Map<String, dynamic> : null;
      rates = first?['vMultiStreamInfo'] as List<dynamic>?;
    }
    return rates ?? [];
  }

  Map<String, dynamic> _parseMeta(String body) {
    final out = <String, dynamic>{
      'nickname': '', 'avatar': '', 'fans': 0, 'heat': 0, 'title': '',
      'isLive': false, 'uid': 0, 'topSid': 0, 'subSid': 0, 'startTime': 0,
    };
    try {
      final m = RegExp(r'HNF_GLOBAL_INIT\s*=\s*\{(.*?)\}\s*;?\s*</script>', dotAll: true).firstMatch(body);
      if (m != null) {
        final json = jsonDecode('{${m.group(1)}}') as Map<String, dynamic>;
        final roomInfo = json['roomInfo'] as Map<String, dynamic>?;
        if (roomInfo != null) {
          final profile = (roomInfo['tProfileInfo'] as Map<String, dynamic>?) ?? {};
          final liveInfo = (roomInfo['tLiveInfo'] as Map<String, dynamic>?) ?? {};
          out['nickname'] = _s(profile['sNick']);
          out['avatar'] = _s(profile['sAvatar180'] ?? profile['sAvatar']);
          out['fans'] = _firstNonZero([profile['lSubscribeCount'], profile['lFansCount']]);
          out['heat'] = _firstNonZero([liveInfo['totalCount'], liveInfo['userCount']]);
          out['title'] = _s(liveInfo['sIntroduction']);
          out['isLive'] = _i(liveInfo['eLiveStatus']) == 2;
          out['startTime'] = _i(liveInfo['iStartTime'] ?? liveInfo['lStartTime']);
          out['uid'] = _i(profile['lUid']);
          out['topSid'] = _i(liveInfo['lChannelId'] ?? profile['lChannelId']);
          out['subSid'] = _i(liveInfo['lSubChannelId']);
        }
      }
    } catch (_) {}
    if (_i(out['topSid']) == 0) out['topSid'] = out['uid'];
    if (_i(out['subSid']) == 0) out['subSid'] = out['topSid'];
    return out;
  }

  Future<HuyaStreamResult?> _resolveByDtv(String roomId) async {
    try {
      var html = await _fetchHtml(roomId, false);
      var block = _parseStreamBlock(html);
      var candidates = _parseCandidates(block);
      var rates = _parseRates(block);
      if (candidates.isEmpty) {
        html = await _fetchHtml(roomId, true);
        block = _parseStreamBlock(html);
        candidates = _parseCandidates(block);
        if (rates.isEmpty) rates = _parseRates(block);
      }
      if (candidates.isEmpty) return null;

      var meta = _parseMeta(html);
      
      int typeRank(String key) => key.startsWith('hls:') ? 0 : 1; // ★ HLS 永远排前面
      int cdnRank(String key) {
        switch (_cdnOf(key).toLowerCase()) {
          case 'al': return 0;
          case 'hs': return 1;
          case 'tx': return 2;
          default: return 3;
        }
      }
      candidates.sort((a, b) {
        final t = typeRank(a.key).compareTo(typeRank(b.key));
        if (t != 0) return t;
        return cdnRank(a.key).compareTo(cdnRank(b.key));
      });

      final rateList = rates.isNotEmpty ? rates : <dynamic>[{'sDisplayName': '原画', 'iBitRate': 0}];
      final qualities = <StreamQuality>[];
      
      for (final r in rateList) {
        final rr = r as Map<String, dynamic>;
        final bitrate = _i(rr['iBitRate']);
        final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
        final urls = candidates.map((e) => '${_adjustTxStreamUrl(e.value, _cdnOf(e.key))}$ratio').toList();
        if (urls.isEmpty) continue;
        final name = _s(rr['sDisplayName']).isEmpty ? (bitrate == 0 ? '原画' : '蓝光${bitrate ~/ 1000}M') : _s(rr['sDisplayName']);
        qualities.add(StreamQuality(name: name, bitrate: bitrate, candidates: urls));
      }
      if (qualities.isEmpty) return null;

      return HuyaStreamResult(
        roomId: roomId, ayyuid: _i(meta['uid']), topSid: _i(meta['topSid']),
        subSid: _i(meta['subSid']), presenterUid: _i(meta['uid']),
        streamerInfo: StreamerInfo(uid: _i(meta['uid']), nickname: _s(meta['nickname']), avatar: _s(meta['avatar']), fansCount: _i(meta['fans']), isLive: meta['isLive'] == true),
        title: _s(meta['title']), isLive: meta['isLive'] == true, heat: _i(meta['heat']),
        startTime: _i(meta['startTime']), qualities: qualities,
      );
    } catch (_) { return null; }
  }

  Future<HuyaStreamResult?> resolveStream(String roomId, {int loginUid = 0}) async {
    return await _resolveByDtv(roomId);
  }
}

class HuyaStreamResult {
  final String roomId; final int ayyuid; final int topSid; final int subSid; final int presenterUid;
  final StreamerInfo streamerInfo; final String title; final bool isLive; final int heat;
  final int startTime; final List<StreamQuality> qualities;

  HuyaStreamResult({
    required this.roomId, this.ayyuid = 0, this.topSid = 0, this.subSid = 0,
    required this.presenterUid, required this.streamerInfo, required this.title,
    required this.isLive, this.heat = 0, this.startTime = 0, required this.qualities,
  });
}
