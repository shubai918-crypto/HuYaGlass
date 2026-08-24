import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';
import 'huya_login.dart';

/// 虎牙直播流解析：纯官方 API 解析（精准映射 activityCount 等字段）
class HuyaStreamResolver {
  static const _iosMobileUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
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

  static String enforceHttp(String url) =>
      url.startsWith('https://') ? url.replaceFirst('https://', 'http://') : url;

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
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  String _trimSlash(String u) {
    var s = u.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  // ================= dtv 同款签名 =================
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
      final uuidSeed =
          (t13 % 10000000000) * 1000 + (_random.nextDouble() * 1000).floor();
      final initUuid = uuidSeed % 4294967295;

      final wsSecretHash = _md5('$seqId|$ctype|$paramsT');
      final wsSecretPlain =
          '${wsPrefix}_${uid}_${streamName}_${wsSecretHash}_$wsTime';
      final wsSecretMd5 = _md5(wsSecretPlain);

      return [
        'wsSecret=$wsSecretMd5',
        'wsTime=$wsTime',
        'seqid=$seqId',
        'ctype=$ctype',
        'ver=1',
        'fs=$fs',
        'uuid=$initUuid',
        'u=$uid',
        't=$paramsT',
        'sv=$_sdkVersion',
        'sdk_sid=$sdkSid',
        'codec=264',
      ].join('&');
    } catch (_) {
      return '';
    }
  }

  String _adjustTxStreamUrl(String url, String cdn) {
    if (cdn.toLowerCase() != 'tx') return enforceHttp(url);
    var s = url.replaceAll('&ctype=tars_mp', '&ctype=huya_webh5');
    s = s.replaceAll('&fs=bhct', '&fs=bgct');
    return enforceHttp(s);
  }

  // ================= 纯官方 API 解析 =================
  Future<HuyaStreamResult?> resolveStream(String roomId,
      {int loginUid = 0}) async {
    try {
      final loginCookie = HuyaLoginManager().cookie;
      final res = await http.get(
        Uri.parse(
            'https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId&showSecret=1'),
        headers: {
          'User-Agent': _iosMobileUa,
          'Referer': 'https://www.huya.com/',
          if (loginCookie.isNotEmpty) 'Cookie': loginCookie,
        },
      );
      if (res.statusCode != 200) return null;
      final root = jsonDecode(res.body) as Map<String, dynamic>;
      if (_i(root['status']) != 200) return null;
      final data = root['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      // ★ 核心字段提取（严格对齐官方 JSON 结构）
      final profile = (data['profileInfo'] as Map<String, dynamic>?) ?? {};
      final liveData = (data['liveData'] as Map<String, dynamic>?) ?? {};

      final liveStatus = _s(data['liveStatus']).toUpperCase();
      final realLiveStatus = _s(data['realLiveStatus']).toUpperCase();
      final isLive = liveStatus == 'ON' || realLiveStatus == 'ON';

      final nickname = _s(liveData['nick']).isNotEmpty
          ? _s(liveData['nick'])
          : _s(profile['nick']);
      final avatar = _s(liveData['avatar180']).isNotEmpty
          ? _s(liveData['avatar180'])
          : _s(profile['avatar180']);

      // ★ 粉丝数：精准读取 activityCount
      final fansCount =
          _firstNonZero([profile['activityCount'], liveData['activityCount']]);

      // 热度：totalCount / attendeeCount
      final heat =
          _firstNonZero([liveData['totalCount'], liveData['attendeeCount']]);

      final title = _s(liveData['introduction']);
      final startTime = _i(liveData['startTime']);
      final cover = _s(liveData['screenshot']);

      final topSid = _firstNonZero(
          [data['chTopId'], liveData['liveChannel'], profile['yyid']]);
      final subSid = _firstNonZero([data['subChId'], liveData['shortChannel']]);
      final uid =
          _firstNonZero([profile['yyid'], profile['uid'], liveData['yyid']]);

      // 解析流地址（API 返回 stream 字段时）
      final stream = (data['stream'] as Map<String, dynamic>?) ?? {};
      final baseList = (stream['baseSteamInfoList'] as List<dynamic>?) ??
          (stream['gameStreamInfoList'] as List<dynamic>?) ??
          [];

      var rates = <dynamic>[];
      final bitRateInfo = liveData['bitRateInfo'];
      if (bitRateInfo is String && bitRateInfo.isNotEmpty) {
        try {
          rates = jsonDecode(bitRateInfo) as List<dynamic>;
        } catch (_) {}
      }
      if (rates.isEmpty) {
        rates = ((stream['flv'] as Map<String, dynamic>?)?['rateArray']
                as List<dynamic>?) ??
            (stream['vMultiStreamInfo'] as List<dynamic>?) ??
            [];
      }

      final qualities = <StreamQuality>[];
      if (baseList.isNotEmpty) {
        final rateList = rates.isNotEmpty
            ? rates
            : <dynamic>[
                {'sDisplayName': '原画', 'iBitRate': 0}
              ];
        for (final r in rateList) {
          final rr = r as Map<String, dynamic>;
          final bitrate = _i(rr['iBitRate']);
          final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
          final urls = <String>[];

          // HLS 优先
          for (final b in baseList) {
            final bm = b as Map<String, dynamic>;
            final streamName = _s(bm['sStreamName']);
            final cdn = _s(bm['sCdnType']);
            final hlsUrl = _trimSlash(_s(bm['sHlsUrl']));
            final hlsSuffix = _s(bm['sHlsUrlSuffix']).isEmpty
                ? 'm3u8'
                : _s(bm['sHlsUrlSuffix']);
            final hlsAnti = _s(bm['sHlsAntiCode']);
            if (hlsUrl.isNotEmpty &&
                streamName.isNotEmpty &&
                hlsAnti.isNotEmpty) {
              final p = generateWebAntiCode(streamName, hlsAnti);
              if (p.isNotEmpty) {
                urls.add(
                    '${_adjustTxStreamUrl(enforceHttp('$hlsUrl/$streamName.$hlsSuffix?$p'), cdn)}$ratio');
              }
            }
          }
          // FLV 兜底
          for (final b in baseList) {
            final bm = b as Map<String, dynamic>;
            final streamName = _s(bm['sStreamName']);
            final cdn = _s(bm['sCdnType']);
            final flvUrl = _trimSlash(_s(bm['sFlvUrl']));
            final flvSuffix = _s(bm['sFlvUrlSuffix']).isEmpty
                ? 'flv'
                : _s(bm['sFlvUrlSuffix']);
            final flvAnti = _s(bm['sFlvAntiCode']);
            if (flvUrl.isNotEmpty &&
                streamName.isNotEmpty &&
                flvAnti.isNotEmpty) {
              final p = generateWebAntiCode(streamName, flvAnti);
              if (p.isNotEmpty) {
                urls.add(
                    '${_adjustTxStreamUrl(enforceHttp('$flvUrl/$streamName.$flvSuffix?$p'), cdn)}$ratio');
              }
            }
          }
          if (urls.isEmpty) continue;
          final name = _s(rr['sDisplayName']).isEmpty
              ? (bitrate == 0 ? '原画' : '蓝光${bitrate ~/ 1000}M')
              : _s(rr['sDisplayName']);
          qualities.add(StreamQuality(
              name: name, bitrate: bitrate, candidates: urls));
        }
      }

      return HuyaStreamResult(
        roomId: roomId,
        ayyuid: _i(uid),
        topSid: _i(topSid),
        subSid: _i(subSid),
        presenterUid: _i(uid),
        streamerInfo: StreamerInfo(
          uid: _i(uid),
          nickname: nickname,
          avatar: avatar,
          fansCount: _i(fansCount),
          isLive: isLive,
        ),
        title: title,
        isLive: isLive,
        heat: _i(heat),
        startTime: startTime,
        cover: cover,
        qualities: qualities,
      );
    } catch (_) {
      return null;
    }
  }
}

class HuyaStreamResult {
  final String roomId;
  final int ayyuid;
  final int topSid;
  final int subSid;
  final int presenterUid;
  final StreamerInfo streamerInfo;
  final String title;
  final bool isLive;
  final int heat;
  final int startTime;
  final String cover;
  final List<StreamQuality> qualities;

  HuyaStreamResult({
    required this.roomId,
    this.ayyuid = 0,
    this.topSid = 0,
    this.subSid = 0,
    required this.presenterUid,
    required this.streamerInfo,
    required this.title,
    required this.isLive,
    this.heat = 0,
    this.startTime = 0,
    this.cover = '',
    required this.qualities,
  });
}
