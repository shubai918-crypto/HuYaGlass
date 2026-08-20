import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'huya_login.dart';

class DanmakuMessage {
  final String nickname;
  final String content;
  final int fontColor;
  DanmakuMessage({
    required this.nickname,
    required this.content,
    this.fontColor = 0xFFFFFFFF,
  });
}

/// 虎牙弹幕客户端（纯 WUP 路线）
/// 信封严格对齐 JS Wup.encode()：4字节长度前缀 + tag7=内层map字节流
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  static const _appUa = 'adr&7.11.82&Pixel 5&31';
  static const _appHuYaUA = 'adr&7.11.82&2052&34';

  static const _endpoints = [
    'wss://wsapi.huya.com',
    'wss://cdnws.api.huya.com',
  ];

  WebSocket? _ws;
  Timer? _heartTimer;
  Timer? _secondRegTimer;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _recvCount = 0;
  int _lastType = -1;
  int _lastUri = -1;
  int _endpointIndex = 0;
  int _topSid = 0;
  int _subSid = 0;
  int _ayyuid = 0;
  int _reqId = 0;
  String? _pendingDanmaku;

  int _loginUid = 0;
  String _guid = '';
  String _token = '';
  String _cookie = '';

  void Function(String)? onStatus;
  void Function(int)? onPopularity;
  void Function(String)? onSendDebug;

  final List<String> _dbg = [];
  void _dbgPush(String s) {
    _dbg.add(s);
    if (_dbg.length > 4) _dbg.removeAt(0);
    onSendDebug?.call(_dbg.join(' | '));
  }

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();

  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  String _cookieVal(String name) {
    final m = RegExp('$name=([^;]+)').firstMatch(_cookie);
    return m?.group(1)?.trim() ?? '';
  }

  // ================= 连接 =================
  Future<void> connect({
    required int topSid,
    required int subSid,
    int uid = 0,
    String roomIdStr = '',
  }) async {
    _closed = false;
    _recvCount = 0;
    _lastType = -1;
    _lastUri = -1;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid > 0 ? uid : topSid;

    _cookie = HuyaLoginManager().cookie;
    _loginUid = int.tryParse(_cookieVal('yyuid')) ??
        (int.tryParse(_cookieVal('udb_uid')) ?? 0);
    _guid = _cookieVal('guid');
    _token = _cookieVal('udb_biztoken');

    onStatus?.call('弹幕连接中…');
    WebSocket? ws;
    for (var i = 0; i < _endpoints.length; i++) {
      if (_closed) return;
      final ep = _endpoints[(_endpointIndex + i) % _endpoints.length];
      try {
        ws = await WebSocket.connect(ep, headers: {
          'Origin': 'https://www.huya.com',
          'User-Agent': _ua,
        }).timeout(const Duration(seconds: 6));
        _endpointIndex = (_endpointIndex + i) % _endpoints.length;
        break;
      } catch (_) {}
    }
    if (ws == null) {
      onStatus?.call('弹幕连接失败');
      _scheduleReconnect();
      return;
    }
    _ws = ws;
    onStatus?.call('弹幕已连接，注册中…');
    ws.listen(_onData, onDone: _onDone, onError: (_) => _onDone(), cancelOnError: true);

    _send(_buildRegister(_ayyuid, _ayyuid));
    _secondRegTimer?.cancel();
    _secondRegTimer = Timer(const Duration(seconds: 1), () {
      if (_topSid > 0) _send(_buildRegister(_topSid, _subSid));
      if (_loginUid > 0) _send(_buildVerifyCookie());
      _send(_wrapWsCmd(_buildWupEnvelope('launch', 'wsLaunch', {
        'tReq': _buildLaunchReq(),
      }), 3));
    });

    _heartTimer?.cancel();
    _heartTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _sendHeartbeat());
  }

  Uint8List _buildLaunchReq() {
    final dev = _TarsWriter();
    dev.writeString(0, '');
    dev.writeString(1, '');
    dev.writeString(2, 'wifi');
    dev.writeString(3, _guid);
    dev.writeString(4, '');
    final req = _TarsWriter();
    req.writeInt(0, _loginUid);
    req.writeString(1, _guid);
    req.writeString(2, _cookieVal('huya_ua').isEmpty ? 'webh5&0.1.0&websocket' : _cookieVal('huya_ua'));
    req.writeString(3, 'webh5&CN&2052');
    req.writeStruct(4, dev);
    return req.toBytes();
  }

  Uint8List _buildRegister(int liveId, int chatId) {
    final group = _TarsWriter();
    group.writeStringList(0, ['live:$liveId', 'chat:$chatId']);
    group.writeString(1, '');
    final command = _TarsWriter();
    command.writeInt(0, 16);
    command.writeBytes(1, group.toBytes());
    return command.toBytes();
  }

  Uint8List _buildVerifyCookie() {
    final req = _TarsWriter();
    req.writeInt(0, _loginUid);
    req.writeString(1, _cookieVal('huya_ua').isEmpty ? 'webh5&0.1.0&websocket' : _cookieVal('huya_ua'));
    req.writeString(2, _cookie);
    req.writeString(3, _guid);
    req.writeInt(4, 1);
    req.writeString(5, 'web');
    final command = _TarsWriter();
    command.writeInt(0, 10);
    command.writeBytes(1, req.toBytes());
    return command.toBytes();
  }

  void _sendHeartbeat() {
    final command = _TarsWriter();
    command.writeInt(0, 20);
    command.writeBytes(1, const []);
    _send(command.toBytes());
  }

  // ================= 真实发送（WUP over HTTP 主通道） =================
  Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0) return false;
    try {
      _pendingDanmaku = text;
      _dbgPush('发送"$text"');
      _tryHttpSend(text);
      _send(_wrapWsCmd(_buildWupSend(text, 'liveui'), 3));
      Timer(const Duration(milliseconds: 800), () {
        if (!_closed && _pendingDanmaku == text) {
          _send(_wrapWsCmd(_buildWupSend(text, 'GameLive'), 3));
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _dohResolve(String host) async {
    final urls = [
      'https://dns.alidns.com/resolve?name=$host&type=A',
      'https://doh.pub/dns-query?name=$host&type=A',
    ];
    for (final u in urls) {
      try {
        final res = await http
            .get(Uri.parse(u), headers: {'User-Agent': _ua})
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body) as Map<String, dynamic>;
          final answers = (j['Answer'] as List?) ?? [];
          final ips = <String>[];
          for (final a in answers) {
            final d = '${(a as Map)['data'] ?? ''}';
            if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(d)) ips.add(d);
          }
          if (ips.isNotEmpty) return ips;
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> _tryHttpSend(String text) async {
    final ips = await _dohResolve('cdn.wup.huya.com');
    final wupLiveui = _buildWupSend(text, 'liveui');
    final wupGameLive = _buildWupSend(text, 'GameLive');
    final ts = DateTime.now().millisecondsSinceEpoch;

    // 组合矩阵：IP直连 × Host × servant，找出能返回 200 的组合
    final targets = <List<String>>[
      for (final ip in ips) ...[
        ['http://$ip:80/?timestamp=$ts', 'cdn.wup.huya.com', 'liveui'],
        ['http://$ip:80/?timestamp=$ts', 'wup.huya.com', 'liveui'],
      ],
      ['http://wup.huya.com:80/?timestamp=$ts', 'wup.huya.com', 'liveui'],
      ['https://wup.huya.com/?timestamp=$ts', 'wup.huya.com', 'liveui'],
    ];

    bool got200 = false;
    for (final t in targets) {
      final url = t[0], host = t[1], servant = t[2];
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/octet-stream',
                'User-Agent': _appUa,
                'Host': host,
                if (_cookie.isNotEmpty) 'Cookie': _cookie,
              },
              body: servant == 'liveui' ? wupLiveui : wupGameLive,
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          got200 = true;
          _dbgPush('✔ $host/$servant → ${_describeWupRsp(res.bodyBytes)}');
        } else {
          _dbgPush('$host/$servant:${res.statusCode}');
        }
      } catch (_) {
        _dbgPush('$host/$servant:ERR');
      }
    }

    // 全失败时补一发 GameLive 到首个 IP
    if (!got200 && ips.isNotEmpty) {
      try {
        final res = await http
            .post(
              Uri.parse('http://${ips.first}:80/?timestamp=$ts'),
              headers: {
                'Content-Type': 'application/octet-stream',
                'User-Agent': _appUa,
                'Host': 'cdn.wup.huya.com',
                if (_cookie.isNotEmpty) 'Cookie': _cookie,
              },
              body: wupGameLive,
            )
            .timeout(const Duration(seconds: 5));
        _dbgPush('补 GameLive:${res.statusCode}');
      } catch (_) {}
    }
  }

  /// 跳过 4 字节长度前缀后读 RequestPacket 字段
  Map<int, Object?> _readWupFields(List<int> bytes) {
    var start = 0;
    if (bytes.length > 4) {
      final prefix =
          (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      if (prefix == bytes.length) start = 4;
    }
    return _TarsReader(Uint8List.fromList(bytes.sublist(start))).readFields();
  }

  String _describeWupRsp(List<int> bytes) {
    try {
      final f = _readWupFields(bytes);
      final servant = '${f[5] ?? ''}';
      final func = '${f[6] ?? ''}';
      int ret = -99;
      final sb = f[7];
      if (sb is List) {
        final inner = _TarsReader(Uint8List.fromList(
                sb.map((e) => (e as int) & 0xFF).toList()))
            .readFields();
        final map = inner[0];
        if (map is List) {
          for (var i = 0; i + 1 < map.length; i += 2) {
            if ('${map[i]}' == 'tRsp' && map[i + 1] is List) {
              final rsp = _TarsReader(Uint8List.fromList(
                      (map[i + 1] as List).map((e) => (e as int) & 0xFF).toList()))
                  .readFields();
              ret = rsp[0] is int ? rsp[0] as int : -99;
            }
          }
        }
      }
      return '$servant.$func iRet=$ret';
    } catch (_) {
      return '解析失败';
    }
  }

  /// WUP 信封 —— 严格对齐 JS encode()：长度前缀 + tag7=内层map字节流
  Uint8List _buildWupEnvelope(
      String servant, String funcName, Map<String, List<int>> buffers) {
    // 内层 newdata：tag 0 -> map<string, BinBuffer>
    final inner = _TarsWriter();
    inner.writeBytesMap(0, buffers);

    final wup = _TarsWriter();
    wup.writeInt(1, 3); // iVersion
    wup.writeInt(2, 0); // cPacketType
    wup.writeInt(3, 0); // iMessageType
    wup.writeInt(4, ++_reqId); // iRequestId
    wup.writeString(5, servant); // sServantName
    wup.writeString(6, funcName); // sFuncName
    wup.writeBytes(7, inner.toBytes()); // sBuffer = BYTES！
    wup.writeInt(8, 0); // iTimeout
    wup.writeBytesMap(9, const {}); // context
    wup.writeBytesMap(10, const {}); // status

    final body = wup.toBytes();
    final total = body.length + 4;
    final out = BytesBuilder();
    out.addByte((total >> 24) & 0xFF);
    out.addByte((total >> 16) & 0xFF);
    out.addByte((total >> 8) & 0xFF);
    out.addByte(total & 0xFF);
    out.add(body);
    return out.toBytes();
  }

  /// SendMessageReq（含 lPid@8）
  Uint8List _buildWupSend(String text, String servant) {
    final user = _TarsWriter();
    user.writeInt(0, _loginUid);
    user.writeString(1, _guid);
    user.writeString(2, _token);
    user.writeString(3, _appHuYaUA);
    user.writeString(4, _cookie);
    user.writeInt(5, 0);
    user.writeString(6, 'Pixel 5');

    final cf = _TarsWriter();
    cf.writeInt(0, -1);
    cf.writeInt(1, 4);
    cf.writeInt(2, 0);
    cf.writeInt(3, -1);

    final bf = _TarsWriter();
    bf.writeInt(0, -1);
    bf.writeInt(1, 4);
    bf.writeInt(2, 1);
    bf.writeInt(3, 0);
    bf.writeInt(4, 0);

    final req = _TarsWriter();
    req.writeStruct(0, user);
    req.writeInt(1, _topSid);
    req.writeInt(2, _subSid);
    req.writeString(3, text.replaceAll('\n', ' '));
    req.writeInt(4, 0);
    req.writeStruct(5, cf);
    req.writeStruct(6, bf);
    req.writeInt(8, _ayyuid); // lPid 主播UID

    return _buildWupEnvelope(servant, 'sendMessage', {'tReq': req.toBytes()});
  }

  Uint8List _wrapWsCmd(Uint8List wup, int cmdType) {
    final command = _TarsWriter();
    command.writeInt(0, cmdType);
    command.writeBytes(1, wup);
    return command.toBytes();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_closed) {
        _endpointIndex = (_endpointIndex + 1) % _endpoints.length;
        connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid);
      }
    });
  }

  void _onDone() {
    _heartTimer?.cancel();
    _secondRegTimer?.cancel();
    if (_closed) return;
    _scheduleReconnect();
  }

  void _send(List<int> data) {
    try {
      if (_ws != null && _ws!.readyState == WebSocket.open) _ws!.add(data);
    } catch (_) {}
  }

  void disconnect() {
    _closed = true;
    _heartTimer?.cancel();
    _secondRegTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  // ================= 收包 =================
  void _onData(dynamic data) {
    try {
      _recvCount++;
      final bytes = Uint8List.fromList((data as List).cast<int>());
      final reader = _TarsReader(bytes);
      final fields = reader.readFields();
      final type = fields[0] is int ? fields[0] as int : -1;
      _lastType = type;

      final payload = fields[1];
      if (payload is List) {
        final pBytes = payload.map((e) => (e as int) & 0xFF).toList();
        final pr = _TarsReader(Uint8List.fromList(pBytes));
        if (type == 7) {
          final pf = pr.readFields();
          final uri = pf[1] is int ? pf[1] as int : 0;
          _lastUri = uri;
          final msg = pf[2];
          if (msg is List) {
            _decodePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
          }
        } else if (type == 22) {
          final pf = pr.readFields();
          final items = pf[1];
          if (items is List) {
            for (final item in items) {
              if (item is Map<int, Object?>) {
                final uri = item[0] is int ? item[0] as int : 0;
                _lastUri = uri;
                final msg = item[1];
                if (msg is List) {
                  _decodePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
                }
              }
            }
          }
        } else if (type == 4) {
          _dbgPush('WS WupRsp ${_describeWupRsp(pBytes)}');
        } else if (type == 11) {
          try {
            final pf = pr.readFields();
            final v = pf[0] is int ? pf[0] as int : -1;
            _dbgPush('VerifyCookie iValidate=$v');
          } catch (_) {}
        }
      }
      onStatus?.call('收包$_recvCount type=$_lastType uri=$_lastUri');
    } catch (_) {}
  }

  void _decodePush(int uri, List<int> payload) {
    if (uri == 1400) {
      try {
        final reader = _TarsReader(Uint8List.fromList(payload));
        final fields = reader.readFields();
        final content = fields[3];
        if (content is String && content.isNotEmpty) {
          final sender =
              fields[0] is Map<int, Object?> ? fields[0] as Map<int, Object?> : null;
          final nick = '${sender?[2] ?? ''}';
          final bf =
              fields[6] is Map<int, Object?> ? fields[6] as Map<int, Object?> : null;
          final color = bf?[0] is int ? bf![0] as int : 0;
          _controller.add(DanmakuMessage(
            nickname: nick,
            content: content,
            fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000),
          ));
          if (_pendingDanmaku != null && content == _pendingDanmaku) {
            _pendingDanmaku = null;
            _dbgPush('弹幕回显成功 ✔');
          }
        }
      } catch (_) {}
    } else if (uri == 8006) {
      try {
        final reader = _TarsReader(Uint8List.fromList(payload));
        final fields = reader.readFields();
        final v = fields[0] is int ? fields[0] as int : 0;
        if (v > 0) onPopularity?.call(v);
      } catch (_) {}
    }
  }
}

// ================= Tars 编码 =================
class _TarsWriter {
  final BytesBuilder _b = BytesBuilder();

  void _head(int tag, int type) {
    if (tag < 15) {
      _b.addByte((tag << 4) | type);
    } else {
      _b.addByte(0xF0 | type);
      _b.addByte(tag);
    }
  }

  int _intType(int v) {
    if (v == 0) return 12;
    if (v >= -128 && v <= 127) return 0;
    if (v >= -32768 && v <= 32767) return 1;
    if (v >= -2147483648 && v <= 2147483647) return 2;
    return 3;
  }

  void _add(int v, int n) {
    for (var i = n - 1; i >= 0; i--) {
      _b.addByte((v >> (8 * i)) & 0xFF);
    }
  }

  void _intValue(int v) {
    final t = _intType(v);
    if (t == 12) return;
    _b.addByte(t);
    _add(v, [1, 2, 4, 8][t]);
  }

  void writeInt(int tag, int v) {
    final t = _intType(v);
    _head(tag, t);
    if (t == 12) return;
    _add(v, [1, 2, 4, 8][t]);
  }

  void writeString(int tag, String s) {
    final b = utf8.encode(s);
    if (b.length < 256) {
      _head(tag, 6);
      _b.addByte(b.length);
    } else {
      _head(tag, 7);
      _add(b.length, 4);
    }
    _b.add(b);
  }

  void writeStringList(int tag, List<String> items) {
    _head(tag, 9);
    _intValue(items.length);
    for (final s in items) {
      writeString(0, s);
    }
  }

  void writeBytes(int tag, List<int> bytes) {
    _head(tag, 13);
    _head(0, 0);
    _intValue(bytes.length);
    _b.add(bytes);
  }

  void writeBytesMap(int tag, Map<String, List<int>> entries) {
    _head(tag, 8);
    _intValue(entries.length);
    entries.forEach((k, v) {
      writeString(0, k);
      writeBytes(1, v);
    });
  }

  void writeStruct(int tag, _TarsWriter inner) {
    _head(tag, 10);
    _b.add(inner._b.toBytes());
    _b.addByte(0x0B);
  }

  Uint8List toBytes() => Uint8List.fromList(_b.toBytes());
}

// ================= Tars 解码 =================
class _TarsReader {
  final Uint8List _d;
  int _pos = 0;
  _TarsReader(this._d);

  bool get hasMore => _pos < _d.length;
  int _byte() => _d[_pos++];

  int _readIntN(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      v = (v << 8) | _d[_pos++];
    }
    final shift = 64 - 8 * n;
    return (v << shift) >> shift;
  }

  int _readValueInt() {
    final t = _byte();
    switch (t) {
      case 0:
        return _readIntN(1);
      case 1:
        return _readIntN(2);
      case 2:
        return _readIntN(4);
      case 3:
        return _readIntN(8);
      case 12:
        return 0;
      default:
        throw FormatException('tars: not an int, type=$t');
    }
  }

  Map<int, Object?> readFields() {
    final m = <int, Object?>{};
    while (hasMore) {
      final h = _byte();
      final type = h & 0x0F;
      if (type == 11) return m;
      var tag = (h >> 4) & 0x0F;
      if (tag == 15) tag = _byte();
      m[tag] = _readValue(type);
    }
    return m;
  }

  Object? _readValue(int type) {
    switch (type) {
      case 0:
        return _readIntN(1);
      case 1:
        return _readIntN(2);
      case 2:
        return _readIntN(4);
      case 3:
        return _readIntN(8);
      case 12:
        return 0;
      case 4:
        final v = ByteData.sublistView(_d, _pos, _pos + 4).getFloat32(0);
        _pos += 4;
        return v;
      case 5:
        final v = ByteData.sublistView(_d, _pos, _pos + 8).getFloat64(0);
        _pos += 8;
        return v;
      case 6:
        final n = _byte();
        final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true);
        _pos += n;
        return s;
      case 7:
        final n = _readIntN(4);
        final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true);
        _pos += n;
        return s;
      case 13:
        _byte();
        final n = _readValueInt();
        final bytes = _d.sublist(_pos, _pos + n);
        _pos += n;
        return bytes;
      case 9:
        final size = _readValueInt();
        final list = <Object?>[];
        for (var i = 0; i < size; i++) {
          final h = _byte();
          var tag = (h >> 4) & 0x0F;
          if (tag == 15) tag = _byte();
          list.add(_readValue(h & 0x0F));
        }
        return list;
      case 8:
        final size = _readValueInt();
        final list = <Object?>[];
        for (var i = 0; i < size * 2; i++) {
          final h = _byte();
          var tag = (h >> 4) & 0x0F;
          if (tag == 15) tag = _byte();
          list.add(_readValue(h & 0x0F));
        }
        return list;
      case 10:
        return readFields();
      default:
        throw FormatException('tars: unknown type $type');
    }
  }
}
