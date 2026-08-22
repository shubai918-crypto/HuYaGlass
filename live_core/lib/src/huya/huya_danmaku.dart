import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
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

/// 虎牙弹幕客户端（sBuffer 用字节硬构造 map{"tReq":bytes}，确保 08 00 01 06 04 74526571 1d 在位）
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0';
  static const _sendHuYaUA = 'webh5&2608191804&websocket';

  static const _endpoints = [
    'wss://ded35397-ws.va.huya.com',
    'wss://65cecb22-ws.va.huya.com',
    'wss://ws.va.huya.com',
    'wss://wsapi.huya.com',
    'wss://cdnws.api.huya.com',
  ];

  static const _frameRegister660118 =
      '00211d000100bf060c48555941265a482632303532162030613839333136653766303638393661336630316438363464393634636361352c3c6a080003060f6c6976653a31353431353431323934180005010c1e1002010c2010020117df101a011aec1007011f4610010612726576656e75653a3135343135343132393418000201057810010119661001060018000201184b1001011aeb1001180001060f636861743a31353431353431323934180003010578100d0118431005011845100430010b780c8c2c36004c5c6600';

  static const _frameRegister691346 =
      '00211d00010103060c48555941265a482632303532162030613839333136653766303638393661336630316438363464393634636361352c3c6a08000306126c6976653a3132353935333037343232383818000a010c1e1001010c2010010117df101601186310050118931001011a2c1001011a2e1001011aec1006011f46100102016fc7f510030615726576656e75653a313235393533303734323238381800010103e910010617636f6d6d3a313235393533303734323238382d6d7574651800020200124f8010020200124f8210021800010612636861743a3132353935333037343232383818000501057810080117de100101184210010118431005011845100530010b780c8c2c36004c5c6600';

  WebSocket? _ws;
  Timer? _heartTimer;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _recvCount = 0;
  int _lastType = -1;
  int _endpointIndex = 0;
  int _topSid = 0;
  int _subSid = 0;
  int _ayyuid = 0;
  int _reqId = 0;
  int _cmdSeq = 0;
  String? _pendingDanmaku;
  String _roomIdStr = '';
  bool _verified = false;
  bool _registered = false;
  String _traceId = '';

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
    if (_dbg.length > 6) _dbg.removeAt(0);
    onSendDebug?.call(_dbg.join(' | '));
  }

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();
  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  String _cookieVal(String name) {
    final m = RegExp('$name=([^;]+)').firstMatch(_cookie);
    return m?.group(1)?.trim() ?? '';
  }

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _hexHead(List<int> b, int n) {
    final sb = StringBuffer();
    for (var i = 0; i < b.length && i < n; i++) {
      sb.write(b[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  Future<void> connect({
    required int topSid,
    required int subSid,
    int uid = 0,
    String roomIdStr = '',
  }) async {
    _closed = false;
    _recvCount = 0;
    _lastType = -1;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid > 0 ? uid : topSid;
    _roomIdStr = roomIdStr;
    _verified = false;
    _registered = false;
    _cmdSeq = 0;

    _cookie = HuyaLoginManager().cookie;
    _loginUid = int.tryParse(_cookieVal('yyuid')) ??
        (int.tryParse(_cookieVal('udb_uid')) ?? 0);
    _guid = _cookieVal('guid');
    _token = _cookieVal('udb_biztoken');
    _traceId =
        List.generate(16, (_) => '0123456789abcdef'[Random().nextInt(16)]).join();

    onStatus?.call('弹幕连接中…');
    final baseinfo = _buildBaseinfo();
    final urls = [
      for (final ep in _endpoints)
        '$ep/?baseinfo=${Uri.encodeComponent(baseinfo)}'
    ];

    WebSocket? ws;
    String connectedHost = '';
    for (var i = 0; i < urls.length; i++) {
      if (_closed) return;
      final ep = urls[(_endpointIndex + i) % urls.length];
      try {
        ws = await WebSocket.connect(
          ep,
          headers: {
            'Origin': 'https://www.huya.com',
            'User-Agent': _ua,
            'Cache-Control': 'no-cache',
          },
          compression: CompressionOptions.compressionDefault,
        ).timeout(const Duration(seconds: 6));
        _endpointIndex = (_endpointIndex + i) % urls.length;
        connectedHost = Uri.parse(ep).host;
        break;
      } catch (_) {}
    }
    if (ws == null) {
      onStatus?.call('弹幕连接失败');
      _scheduleReconnect();
      return;
    }
    _ws = ws;
    _dbgPush('WS host: $connectedHost');
    onStatus?.call('弹幕已连接，握手中…');
    ws.listen(_onData, onDone: _onDone, onError: (_) => _onDone(), cancelOnError: true);

    _send(_buildVerifyCookie());
    Timer(const Duration(milliseconds: 300), () {
      if (_closed) return;
      _send(_wrapWsCmd(
          _withPrefix(
              _wupBody('launch', 'wsTimeSync', {'tReq': _treq(_buildLaunchReq())})),
          3));
    });
    Timer(const Duration(milliseconds: 600), () {
      if (_closed) return;
      _sendRegister();
    });

    _heartTimer?.cancel();
    _heartTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }

  void _sendRegister() {
    _send(_buildRegisterGroup());
    _registered = true;
    _dbgPush('Register(16) 已发');
  }

  String _buildBaseinfo() {
    final r = Random();
    final mid =
        '${(10000 + r.nextDouble() * 89999).toStringAsFixed(5)},${(10000 + r.nextDouble() * 89999).toStringAsFixed(6)}';
    final info = _TarsWriter();
    info.writeInt(0, _loginUid);
    info.writeString(1, _guid);
    info.writeString(2, _sendHuYaUA);
    info.writeString(3, 'HUYA&ZH&2052');
    info.writeString(4, '');
    info.writeString(5, mid);
    info.writeInt(6, 0);
    info.writeString(7, '');
    info.writeString(8, '');
    info.writeString(9, '');
    info.writeMap(10, const {
      'HUYA_NET': '0',
      'HUYA_VSDKUA': _sendHuYaUA,
    });
    return base64Encode(info.toBytes());
  }

  Uint8List _treq(Uint8List structFields) {
    final out = BytesBuilder();
    out.addByte(0x0A);
    out.add(structFields);
    out.addByte(0x0B);
    return out.toBytes();
  }

  Uint8List _buildLaunchReq() {
    final req = _TarsWriter();
    req.writeString(0, '');
    req.writeInt(1, 668);
    return req.toBytes();
  }

  Uint8List _buildVerifyCookie() {
    final req = _TarsWriter();
    req.writeInt(0, _loginUid);
    req.writeString(1, _sendHuYaUA);
    req.writeString(2, _cookie);
    req.writeString(3, _guid);
    req.writeInt(4, 1);
    req.writeString(5, 'HUYA&ZH&2052');
    final cmd = _TarsWriter();
    cmd.writeInt(0, 10);
    cmd.writeBytes(1, req.toBytes());
    cmd.writeInt(2, 0);
    cmd.writeString(3, '');
    cmd.writeInt(4, 0);
    cmd.writeInt(5, 0);
    cmd.writeString(6, '');
    return cmd.toBytes();
  }

  Uint8List _buildRegisterGroup() {
    final req = _TarsWriter();
    req.writeStringList(0, ['live:$_ayyuid', 'chat:$_ayyuid']);
    req.writeString(1, '');
    final cmd = _TarsWriter();
    cmd.writeInt(0, 16);
    cmd.writeBytes(1, req.toBytes());
    cmd.writeInt(2, ++_reqId);
    return cmd.toBytes();
  }

  void _sendHeartbeat() {
    final cmd = _TarsWriter();
    cmd.writeInt(0, 20);
    cmd.writeBytes(1, const []);
    _send(cmd.toBytes());
  }

Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0) return false;
    if (!_verified || !_registered) {
      _dbgPush('未认证/未注册');
      return false;
    }
    try {
      _pendingDanmaku = text;

      if (_roomIdStr == '660118') {
        _send(_hexToBytes(_frameRegister660118));
      } else if (_roomIdStr == '691346') {
        _send(_hexToBytes(_frameRegister691346));
      }

      final treq = _treq(_buildSendReq(text));

      // ★ sBuffer = map{"tReq": simplelist(treq)}，逐字节硬写，杜绝任何 writer 差异
      final sb = BytesBuilder();
      sb.addByte(0x08); // map head
      sb.addByte(0x00); // size type int8
      sb.addByte(0x01); // size = 1
      sb.addByte(0x06); // key string1
      sb.addByte(0x04); // len 4
      sb.add(utf8.encode('tReq'));
      sb.addByte(0x1D); // value simplelist
      sb.addByte(0x00); // inner head
      sb.addByte(0x01); // len type int16
      sb.addByte((treq.length >> 8) & 0xFF);
      sb.addByte(treq.length & 0xFF);
      sb.add(treq);

      final wup = _TarsWriter();
      wup.writeInt(1, 3);
      wup.writeInt(2, 0);
      wup.writeInt(3, 0);
      wup.writeInt(4, ++_reqId);
      wup.writeString(5, 'liveui');
      wup.writeString(6, 'sendMessage');
      wup.writeBytes(7, sb.toBytes());
      wup.writeInt(8, 0);
      wup.writeInt(9, 0);
      wup.writeInt(10, 0);

      final framed = _withPrefix(wup.toBytes());
      _send(_wrapWsCmd(framed, 3, md5.convert(framed).toString()));
      // ★ 完整 hex 自动进剪贴板，长按粘贴即可
      final fullHex =
          framed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      Clipboard.setData(ClipboardData(text: fullHex));
      _dbgPush('HD 已复制 ${framed.length}B');
      return true;
    } catch (e) {
      _dbgPush('发送异常:$e');
      return false;
    }
  }

  Uint8List _buildSendReq(String text) {
    final user = _TarsWriter();
    user.writeInt(0, _loginUid);
    user.writeString(1, _guid);
    user.writeString(2, '');
    user.writeString(3, _sendHuYaUA);
    user.writeString(4, _cookie);
    user.writeInt(5, 0);
    user.writeString(6, 'edg');
    user.writeString(7, '');

    final cf = _TarsWriter();
    cf.writeInt(0, -1);
    cf.writeInt(1, 4);
    cf.writeInt(2, 0);
    cf.writeInt(3, -1);
    cf.writeInt(4, -1);
    cf.writeInt(5, -1);

    final border = _TarsWriter();
    border.writeInt(0, 0);
    border.writeInt(1, 0);
    border.writeInt(2, -1);
    border.writeInt(3, 100);
    border.writeInt(4, -1);
    border.writeInt(5, 100);
    border.writeString(6, '');
    border.writeInt(7, -1);
    border.writeInt(8, -1);

    final bf = _TarsWriter();
    bf.writeInt(0, -1);
    bf.writeInt(1, 4);
    bf.writeInt(2, 0);
    bf.writeInt(3, 1);
    bf.writeInt(4, 0);
    bf.writeStruct(5, border);
    bf.writeListInt(6, const []);
    bf.writeInt(7, 0);
    bf.writeInt(8, -1);

    final sence = _TarsWriter();
    sence.writeInt(0, 0);
    sence.writeInt(1, 0);
    sence.writeInt(2, 0);

    final req = _TarsWriter();
    req.writeStruct(0, user);
    req.writeInt(1, _topSid);
    req.writeInt(2, _topSid);
    req.writeString(3, text.replaceAll('\n', ' '));
    req.writeInt(4, 0);
    req.writeStruct(5, cf);
    req.writeStruct(6, bf);
    req.writeListInt(7, const []);
    req.writeInt(8, _topSid);
    req.writeListInt(9, const []);
    req.writeStruct(10, sence);
    req.writeInt(11, 0);
    return req.toBytes();
  }

  // ===== Tars 整数字段（带类型头） =====
  void _addInt(BytesBuilder b, int v) {
    if (v == 0) {
      b.addByte(0x00);
    } else if (v >= -128 && v <= 127) {
      b.addByte(0x00);
      b.addByte(v & 0xFF);
    } else if (v >= -32768 && v <= 32767) {
      b.addByte(0x01);
      b.addByte((v >> 8) & 0xFF);
      b.addByte(v & 0xFF);
    } else {
      b.addByte(0x02);
      b.addByte((v >> 24) & 0xFF);
      b.addByte((v >> 16) & 0xFF);
      b.addByte((v >> 8) & 0xFF);
      b.addByte(v & 0xFF);
    }
  }

  /// ★ sBuffer = map{"tReq": simplelist(treq)}，字节硬构造，保证 08 00 01 06 04 74526571 1d 在位
  Uint8List _wupBody(String servant, String func, Map<String, Uint8List> buffers) {
    final inner = BytesBuilder();
    inner.addByte(0x08); // map head
    _addInt(inner, buffers.length); // size
    buffers.forEach((k, v) {
      final kb = utf8.encode(k);
      inner.addByte(0x06); // key string1
      inner.addByte(kb.length);
      inner.add(kb);
      inner.addByte(0x1D); // value simplelist
      inner.addByte(0x00);
      _addInt(inner, v.length);
      inner.add(v);
    });

    final wup = _TarsWriter();
    wup.writeInt(1, 3);
    wup.writeInt(2, 0);
    wup.writeInt(3, 0);
    wup.writeInt(4, ++_reqId);
    wup.writeString(5, servant);
    wup.writeString(6, func);
    wup.writeBytes(7, inner.toBytes());
    wup.writeInt(8, 0);
    wup.writeInt(9, 0);
    wup.writeInt(10, 0);
    return wup.toBytes();
  }

  Uint8List _withPrefix(Uint8List body) {
    final total = body.length + 4;
    final out = BytesBuilder();
    out.addByte((total >> 24) & 0xFF);
    out.addByte((total >> 16) & 0xFF);
    out.addByte((total >> 8) & 0xFF);
    out.addByte(total & 0xFF);
    out.add(body);
    return out.toBytes();
  }

  Uint8List _wrapWsCmd(Uint8List vData, int cmdType, [String? sMd5]) {
    final cmd = _TarsWriter();
    cmd.writeInt(0, cmdType);
    cmd.writeBytes(1, vData);
    cmd.writeInt(2, 0);
    cmd.writeString(3, '$_traceId:$_traceId:0:${_cmdSeq++}');
    cmd.writeInt(4, 0);
    cmd.writeInt(5, 0);
    cmd.writeString(6, sMd5 ?? md5.convert(vData).toString());
    return cmd.toBytes();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_closed) {
        _endpointIndex = (_endpointIndex + 1) % _endpoints.length;
        connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid, roomIdStr: _roomIdStr);
      }
    });
  }

  void _onDone() {
    _heartTimer?.cancel();
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
    _reconnectTimer?.cancel();
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  void _onData(dynamic data) {
    try {
      _recvCount++;
      final bytes = Uint8List.fromList((data as List).cast<int>());
      final reader = _TarsReader(bytes);
      final fields = reader.readFields();
      final cmdType = fields[0] is int ? fields[0] as int : -1;
      _lastType = cmdType;

      final vData = fields[1];
      if (vData is! List) {
        onStatus?.call('收包$_recvCount cmd=$cmdType');
        return;
      }
      final payload =
          Uint8List.fromList(vData.map((e) => (e as int) & 0xFF).toList());

      switch (cmdType) {
        case 11:
          final f = _TarsReader(payload).readFields();
          final v = f[0] is int ? f[0] as int : -1;
          _dbgPush('Verify iValidate=$v');
          if (v == 0) _verified = true;
          break;
        case 17:
          final f = _TarsReader(payload).readFields();
          final v = f[0] is int ? f[0] as int : -1;
          _dbgPush('Register iResCode=$v');
          if (v == 0) _registered = true;
          break;
        case 34:
          final f = _TarsReader(payload).readFields();
          final v = f[0] is int ? f[0] as int : -1;
          _dbgPush('Register34 iResCode=$v');
          break;
        case 4:
          _dbgPush('WupRsp ${_describeWupRsp(payload)}');
          break;
        case 21:
          break;
        case 22:
          _handleMsgPush(payload);
          break;
        case 7:
          _handleMsgPushV1(payload);
          break;
        default:
          _dbgPush('未知cmd=$cmdType len=${payload.length}');
          break;
      }
      onStatus?.call('收包$_recvCount cmd=$cmdType');
    } catch (_) {}
  }

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

  void _handleMsgPush(Uint8List payload) {
    try {
      final f = _TarsReader(payload).readFields();
      final items = f[1];
      if (items is! List) return;
      for (final item in items) {
        if (item is! Map<int, Object?>) continue;
        final uri = item[0] is int ? item[0] as int : 0;
        final msg = item[1];
        if (msg is List) {
          _routePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
        }
      }
    } catch (_) {}
  }

  void _handleMsgPushV1(Uint8List payload) {
    try {
      final f = _TarsReader(payload).readFields();
      final uri = f[1] is int ? f[1] as int : 0;
      final msg = f[2];
      if (msg is List) {
        _routePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
      }
    } catch (_) {}
  }

  void _routePush(int uri, List<int> payload) {
    if (uri == 1400) {
      _decodeDanmaku(payload);
    } else if (uri == 8006) {
      try {
        final f = _TarsReader(Uint8List.fromList(payload)).readFields();
        final v = f[0] is int ? f[0] as int : 0;
        if (v > 0) onPopularity?.call(v);
      } catch (_) {}
    }
  }

  void _decodeDanmaku(List<int> payload) {
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
          _dbgPush('回显确认 ✔');
        }
      }
    } catch (_) {}
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
    writeIntValue(items.length);
    for (final s in items) {
      writeString(0, s);
    }
  }

  void writeIntValue(int v) {
    final t = _intType(v);
    if (t == 12) return;
    _b.addByte(t);
    _add(v, [1, 2, 4, 8][t]);
  }

  void writeListInt(int tag, List<int> items) {
    _head(tag, 9);
    writeIntValue(items.length);
    for (final v in items) {
      writeInt(0, v);
    }
  }

  void writeBytes(int tag, List<int> bytes) {
    _head(tag, 13);
    _head(0, 0);
    writeIntValue(bytes.length);
    _b.add(bytes);
  }

  void writeMap(int tag, Map<String, String> entries) {
    _head(tag, 8);
    writeIntValue(entries.length);
    entries.forEach((k, v) {
      writeString(0, k);
      writeString(1, v);
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
}
