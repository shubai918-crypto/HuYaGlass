import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../model/stream_quality.dart';
import '../model/streamer_info.dart';
import 'huya_login.dart';

/// 虎牙直播流解析：网页(dtv 签名) + 官方 API 双源，HLS 优先 / FLV 兜底
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

  String _cdnOf(String key) {
    final i = key.indexOf(':');
    return i >= 0 ? key.substring(i + 1) : key;
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

  Future<String> _fetchHtml(String roomId, bool mobile) async {
    final loginCookie = HuyaLoginManager().cookie;
    final res = await http.get(
      Uri.parse('https://www.huya.com/$roomId'),
      headers: {
        'User-Agent': mobile ? _iosMobileUa : _desktopUa,
        'Referer': mobile ? 'https://m.huya.com/' : 'https://www.huya.com/',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.6,en;q=0.4',
        'Cookie': loginCookie.isNotEmpty ? loginCookie : _huyaWebh5Cookie,
      },
    );
    return res.statusCode == 200 ? res.body : '';
  }

  Map<String, dynamic>? _parseStreamBlock(String html) {
    try {
      final re =
          RegExp(r'stream:\s*(\{"data".*?),"iWebDefaultBitRate"', dotAll: true);
      final m = re.firstMatch(html);
      if (m == null) return null;
      return jsonDecode('${m.group(1)}}') as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// HLS 优先、FLV 兜底
  List<MapEntry<String, String>> _parseCandidates(Map<String, dynamic>? block) {
    final result = <MapEntry<String, String>>[];
    if (block == null) return result;
    try {
      final dataList = block['data'] as List<dynamic>?;
      final first = (dataList != null && dataList.isNotEmpty)
          ? dataList.first as Map<String, dynamic>
          : null;
      final streamInfoList = first?['gameStreamInfoList'] as List<dynamic>?;
      if (streamInfoList == null) return result;
      for (final item in streamInfoList) {
        final obj = item as Map<String, dynamic>;
        final cdn = _s(obj['sCdnType']);
        final streamName = _s(obj['sStreamName']);
        if (cdn.isEmpty || streamName.isEmpty) continue;

        final hlsUrl = _trimSlash(_s(obj['sHlsUrl']));
        final hlsSuffix =
            _s(obj['sHlsUrlSuffix']).isEmpty ? 'm3u8' : _s(obj['sHlsUrlSuffix']);
        final hlsAnti = _s(obj['sHlsAntiCode']);
        if (hlsUrl.isNotEmpty && hlsAnti.isNotEmpty) {
          final p = generateWebAntiCode(streamName, hlsAnti);
          if (p.isNotEmpty) {
            result.add(MapEntry(
                'hls:$cdn', enforceHttp('$hlsUrl/$streamName.$hlsSuffix?$p')));
          }
        }

        final flvUrl = _trimSlash(_s(obj['sFlvUrl']));
        final flvSuffix =
            _s(obj['sFlvUrlSuffix']).isEmpty ? 'flv' : _s(obj['sFlvUrlSuffix']);
        final flvAnti = _s(obj['sFlvAntiCode']);
        if (flvUrl.isNotEmpty && flvAnti.isNotEmpty) {
          final p = generateWebAntiCode(streamName, flvAnti);
          if (p.isNotEmpty) {
            result.add(MapEntry(
                'flv:$cdn', enforceHttp('$flvUrl/$streamName.$flvSuffix?$p')));
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
      final first = (dataList != null && dataList.isNotEmpty)
          ? dataList.first as Map<String, dynamic>
          : null;
      rates = first?['vMultiStreamInfo'] as List<dynamic>?;
    }
    return rates ?? [];
  }

  // ============ 主播信息：HNF + 全页正则多源兜底 ============
  Map<String, dynamic> _parseMeta(String body) {
    final out = <String, dynamic>{
      'nickname': '',
      'avatar': '',
      'fans': 0,
      'heat': 0,
      'title': '',
      'isLive': false,
      'uid': 0,
      'topSid': 0,
      'subSid': 0,
      'startTime': 0,
    };
    try {
      final m = RegExp(r'HNF_GLOBAL_INIT\s*=\s*\{(.*?)\}\s*;?\s*</script>',
              dotAll: true)
          .firstMatch(body);
      if (m != null) {
        final json = jsonDecode('{${m.group(1)}}') as Map<String, dynamic>;
        final roomInfo = json['roomInfo'] as Map<String, dynamic>?;
        if (roomInfo != null) {
          final profile =
              (roomInfo['tProfileInfo'] as Map<String, dynamic>?) ?? {};
          final liveInfo = (roomInfo['tLiveInfo'] as Map<String, dynamic>?) ?? {};
          out['nickname'] = _s(profile['sNick']);
          out['avatar'] = _s(profile['sAvatar180'] ?? profile['sAvatar']);
          out['fans'] = _firstNonZero([
            profile['lSubscribeCount'],
            profile['iSubscribeCount'],
            profile['lFansCount'],
            profile['iFansCount'],
          ]);
          out['heat'] = _firstNonZero([
            liveInfo['totalCount'],
            liveInfo['userCount'],
            liveInfo['iAttendeeCount'],
            profile['totalCount'],
          ]);
          out['title'] = _s(liveInfo['sIntroduction']);
          out['isLive'] = _i(liveInfo['eLiveStatus']) == 2;
          out['startTime'] = _i(liveInfo['iStartTime'] ?? liveInfo['lStartTime']);
          out['uid'] = _i(profile['lUid']);
          out['topSid'] = _i(liveInfo['lChannelId'] ?? profile['lChannelId']);
          out['subSid'] = _i(liveInfo['lSubChannelId']);
        }
      }
    } catch (_) {}

    // 兜底①：昵称
    if (_s(out['nickname']).isEmpty) {
      for (final re in [
        RegExp(r'"sNick"\s*:\s*"([^"]+)"'),
        RegExp(r'"nick"\s*:\s*"([^"]+)"'),
        RegExp(r'"nickname"\s*:\s*"([^"]+)"'),
      ]) {
        final m = re.firstMatch(body);
        if (m != null) {
          out['nickname'] = m.group(1)!;
          break;
        }
      }
    }
    // 兜底②：头像
    if (_s(out['avatar']).isEmpty) {
      for (final re in [
        RegExp(r'"sAvatar180"\s*:\s*"([^"]+)"'),
        RegExp(r'"sAvatar"\s*:\s*"([^"]+)"'),
        RegExp(r'"avatar"\s*:\s*"(https?://[^"]+)"'),
      ]) {
        final m = re.firstMatch(body);
        if (m != null) {
          out['avatar'] = m.group(1)!;
          break;
        }
      }
    }
    // 兜底③：热度
    if (_i(out['heat']) == 0) {
      final m = RegExp(r'"totalCount"\s*:\s*([1-9]\d*)').firstMatch(body);
      if (m != null) out['heat'] = int.parse(m.group(1)!);
    }
    // ★ 兜底④-a：网页可见文本「粉丝 19.0万」
    if (_i(out['fans']) == 0) {
      final m = RegExp(r'粉丝\s*(?:<[^>]*>\s*)*([\d.]+)\s*(万)?').firstMatch(body);
      if (m != null) {
        var v = double.tryParse(m.group(1)!) ?? 0;
        if (m.group(2) == '万') v *= 10000;
        if (v > 0) out['fans'] = v.round();
      }
    }
    // 兜底④-b：JSON key
    if (_i(out['fans']) == 0) {
      final matches = RegExp(
        r'"(?:lSubscribeCount|iSubscribeCount|lFansCount|iFansCount|fansCount)"\s*:\s*(\d+)',
      ).allMatches(body);
      int maxFans = 0;
      for (final m in matches) {
        final v = int.tryParse(m.group(1)!) ?? 0;
        if (v > maxFans) maxFans = v;
      }
      if (maxFans > 0) out['fans'] = maxFans;
    }
    // 兜底⑤：标题
    if (_s(out['title']).isEmpty) {
      final m = RegExp(r'"sIntroduction"\s*:\s*"([^"]+)"').firstMatch(body);
      if (m != null) out['title'] = m.group(1)!;
    }
    // 兜底⑥：uid / topSid / subSid
    if (_i(out['uid']) == 0) {
      for (final key in ['lPresenterUid', 'lUid', 'yyid']) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(body);
        if (m != null) {
          out['uid'] = int.parse(m.group(1)!);
          break;
        }
      }
    }
    if (_i(out['topSid']) == 0) {
      final m = RegExp(r'"lChannelId"\s*:\s*(\d+)').firstMatch(body);
      if (m != null) out['topSid'] = int.parse(m.group(1)!);
    }
    if (_i(out['subSid']) == 0) {
      final m = RegExp(r'"lSubChannelId"\s*:\s*(\d+)').firstMatch(body);
      if (m != null) out['subSid'] = int.parse(m.group(1)!);
    }
    // 兜底⑦：开播时间
    if (_i(out['startTime']) == 0) {
      for (final key in ['iStartTime', 'lStartTime', 'startTime']) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(body);
        if (m == null) continue;
        var v = int.parse(m.group(1)!);
        if (v > 1000000000000) v ~/= 1000;
        if (v > 1500000000 && v < 2600000000) {
          out['startTime'] = v;
          break;
        }
      }
    }
    // 兜底⑧：有流即视为在播
    if (out['isLive'] != true) {
      if (RegExp(r'"sStreamName"\s*:\s*"[^"]+"').firstMatch(body) != null) {
        out['isLive'] = true;
      }
    }
    if (_i(out['topSid']) == 0) out['topSid'] = _i(out['uid']);
    if (_i(out['subSid']) == 0) out['subSid'] = _i(out['topSid']);
    return out;
  }

  // ================= 网页解析（主） =================
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

      final meta = _parseMeta(html);

      int typeRank(String key) => key.startsWith('hls:') ? 0 : 1;
      int cdnRank(String key) {
        switch (_cdnOf(key).toLowerCase()) {
          case 'al':
            return 0;
          case 'hs':
            return 1;
          case 'tx':
            return 2;
          default:
            return 3;
        }
      }

      candidates.sort((a, b) {
        final t = typeRank(a.key).compareTo(typeRank(b.key));
        if (t != 0) return t;
        return cdnRank(a.key).compareTo(cdnRank(b.key));
      });

      final rateList = rates.isNotEmpty
          ? rates
          : <dynamic>[
              {'sDisplayName': '原画', 'iBitRate': 0}
            ];

      final qualities = <StreamQuality>[];
      for (final r in rateList) {
        final rr = r as Map<String, dynamic>;
        final bitrate = _i(rr['iBitRate']);
        final ratio = bitrate > 0 ? '&ratio=$bitrate' : '';
        final urls = candidates
            .map((e) => '${_adjustTxStreamUrl(e.value, _cdnOf(e.key))}$ratio')
            .toList();
        if (urls.isEmpty) continue;
        final name = _s(rr['sDisplayName']).isEmpty
            ? (bitrate == 0 ? '原画' : '蓝光${bitrate ~/ 1000}M')
            : _s(rr['sDisplayName']);
        qualities
            .add(StreamQuality(name: name, bitrate: bitrate, candidates: urls));
      }
      if (qualities.isEmpty) return null;

      return HuyaStreamResult(
        roomId: roomId,
        ayyuid: _i(meta['uid']),
        topSid: _i(meta['topSid']),
        subSid: _i(meta['subSid']),
        presenterUid: _i(meta['uid']),
        streamerInfo: StreamerInfo(
          uid: _i(meta['uid']),
          nickname: _s(meta['nickname']),
          avatar: _s(meta['avatar']),
          fansCount: _i(meta['fans']),
          isLive: meta['isLive'] == true,
        ),
        title: _s(meta['title']),
        isLive: meta['isLive'] == true,
        heat: _i(meta['heat']),
        startTime: _i(meta['startTime']),
        qualities: qualities,
      );
    } catch (_) {
      return null;
    }
  }

  // ============ 官方 API（兜底，字段 liveData.nick 等） ============
  Future<HuyaStreamResult?> _resolveByApi(String roomId) async {
    try {
      final loginCookie = HuyaLoginManager().cookie;
      final res = await http.get(
        Uri.parse(
            'https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId'),
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

      final liveData = (data['liveData'] as Map<String, dynamic>?) ?? {};
      final profile = (data['profileInfo'] as Map<String, dynamic>?) ?? {};
      final liveInfo = (data['liveInfo'] as Map<String, dynamic>?) ?? {};
      final stream = (data['stream'] as Map<String, dynamic>?) ?? {};
      final base = (stream['baseStream'] as Map<String, dynamic>?) ?? {};

      final isLive = '${data['liveStatus'] ?? ''}'.toUpperCase() == 'ON' ||
          _i(liveData['isOn']) == 1 ||
          _i(liveInfo['eLiveStatus']) == 2 ||
          _s(base['sStreamName']).isNotEmpty;

      final heat = _firstNonZero([
        liveData['totalCount'],
        liveData['userCount'],
        liveInfo['totalCount'],
        liveInfo['userCount'],
      ]);

      final baseList = (stream['baseSteamInfoList'] as List<dynamic>?) ??
          (stream['gameStreamInfoList'] as List<dynamic>?) ??
          [];

      int topSid = _firstNonZero([liveData['tid'], liveInfo['lChannelId']]);
      int subSid = _firstNonZero([liveData['sid'], liveInfo['lSubChannelId']]);
      if (topSid == 0 && baseList.isNotEmpty) {
        final b0 = baseList.first as Map<String, dynamic>;
        topSid = _i(b0['lChannelId']);
        subSid = _i(b0['lSubChannelId']);
      }

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
          for (final b in baseList) {
            final bm = b as Map<String, dynamic>;
            final streamName = _s(bm['sStreamName']);
            final cdn = _s(bm['sCdnType']);
            final hlsUrl = _trimSlash(_s(bm['sHlsUrl']));
            final hlsSuffix = _s(bm['sHlsUrlSuffix']).isEmpty
                ? 'm3u8'
                : _s(bm['sHlsUrlSuffix']);
            final hlsAnti = _s(bm['sHlsAntiCode']);
            if (hlsUrl.isNotEmpty && streamName.isNotEmpty && hlsAnti.isNotEmpty) {
              final p = generateWebAntiCode(streamName, hlsAnti);
              if (p.isNotEmpty) {
                urls.add(
                    '${_adjustTxStreamUrl(enforceHttp('$hlsUrl/$streamName.$hlsSuffix?$p'), cdn)}$ratio');
              }
            }
          }
          for (final b in baseList) {
            final bm = b as Map<String, dynamic>;
            final streamName = _s(bm['sStreamName']);
            final cdn = _s(bm['sCdnType']);
            final flvUrl = _trimSlash(_s(bm['sFlvUrl']));
            final flvSuffix = _s(bm['sFlvUrlSuffix']).isEmpty
                ? 'flv'
                : _s(bm['sFlvUrlSuffix']);
            final flvAnti = _s(bm['sFlvAntiCode']);
            if (flvUrl.isNotEmpty && streamName.isNotEmpty && flvAnti.isNotEmpty) {
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
        ayyuid: _firstNonZero([
          liveData['yyid'],
          profile['yyid'],
          profile['lUid'],
          profile['uid'],
        ]),
        topSid: topSid,
        subSid: subSid,
        presenterUid: _firstNonZero([
          liveData['yyid'],
          profile['yyid'],
          profile['lUid'],
          profile['uid'],
        ]),
        streamerInfo: StreamerInfo(
          uid:
              _firstNonZero([liveData['yyid'], profile['yyid'], profile['lUid']]),
          nickname: _s(liveData['nick']).isNotEmpty
              ? _s(liveData['nick'])
              : _s(profile['sNick'] ?? profile['sPresenterNick']),
          avatar: _s(liveData['avatar180']).isNotEmpty
              ? _s(liveData['avatar180'])
              : _s(profile['sAvatar180'] ?? profile['sAvatar']),
          fansCount: _firstNonZero([
            liveData['fansCount'],
            profile['lSubscribeCount'],
            profile['iSubscribeCount'],
            profile['lFansCount'],
          ]),
          isLive: isLive,
        ),
        title: _s(liveData['introduction']).isNotEmpty
            ? _s(liveData['introduction'])
            : _s(liveInfo['sIntroduction'] ?? liveInfo['sRoomName']),
        isLive: isLive,
        heat: heat,
        startTime: _firstNonZero([
          liveData['startTime'],
          liveData['iStartTime'],
          liveInfo['iStartTime'],
          liveInfo['lStartTime'],
        ]),
        qualities: qualities,
      );
    } catch (_) {
      return null;
    }
  }

  /// 订阅数专用接口
  Future<int> _fetchSubscribeCount(String roomId) async {
    final cookie = HuyaLoginManager().cookie;
    for (final host in ['https://www.huya.com', 'https://mp.huya.com']) {
      try {
        final res = await http.get(
          Uri.parse(
              '$host/cache.php?m=Subscribe&do=getSubscribeCount&roomId=$roomId'),
          headers: {
            'User-Agent': _desktopUa,
            'Referer': 'https://www.huya.com/',
            if (cookie.isNotEmpty) 'Cookie': cookie,
          },
        );
        if (res.statusCode == 200) {
          final body = res.body.trim();
          final direct = int.tryParse(body);
          if (direct != null && direct > 0) return direct;
          final m = RegExp(
                  r'"(?:count|num|subscribeCount|lSubscribeCount)"\s*:\s*(\d+)')
              .firstMatch(body);
          if (m != null) return int.parse(m.group(1)!);
        }
      } catch (_) {}
    }
    return 0;
  }

  // ================= 入口：网页优先，API 补信息 =================
  Future<HuyaStreamResult?> resolveStream(String roomId,
      {int loginUid = 0}) async {
    final dtv = await _resolveByDtv(roomId);
    final api = await _resolveByApi(roomId);
    if (dtv == null && api == null) return null;
    if (dtv == null) return api;
    if (api == null) return dtv;

    var fans = api.streamerInfo.fansCount >= dtv.streamerInfo.fansCount
        ? api.streamerInfo.fansCount
        : dtv.streamerInfo.fansCount;
    if (fans == 0) fans = await _fetchSubscribeCount(roomId);

    return HuyaStreamResult(
      roomId: roomId,
      ayyuid: dtv.ayyuid != 0 ? dtv.ayyuid : api.ayyuid,
      topSid: dtv.topSid != 0 ? dtv.topSid : api.topSid,
      subSid: dtv.subSid != 0 ? dtv.subSid : api.subSid,
      presenterUid: dtv.presenterUid != 0 ? dtv.presenterUid : api.presenterUid,
      streamerInfo: StreamerInfo(
        uid: dtv.presenterUid != 0 ? dtv.presenterUid : api.presenterUid,
        nickname: dtv.streamerInfo.nickname.isNotEmpty
            ? dtv.streamerInfo.nickname
            : api.streamerInfo.nickname,
        avatar: dtv.streamerInfo.avatar.isNotEmpty
            ? dtv.streamerInfo.avatar
            : api.streamerInfo.avatar,
        fansCount: fans,
        isLive: dtv.isLive || api.isLive,
      ),
      title: dtv.title.isNotEmpty ? dtv.title : api.title,
      isLive: dtv.isLive || api.isLive,
      heat: api.heat >= dtv.heat ? api.heat : dtv.heat,
      startTime: dtv.startTime != 0 ? dtv.startTime : api.startTime,
      qualities: dtv.qualities.isNotEmpty ? dtv.qualities : api.qualities,
    );
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
    required this.qualities,
  });
}
