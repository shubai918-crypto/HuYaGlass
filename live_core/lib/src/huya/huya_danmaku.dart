import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

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
  String? _pendingDanmaku;
  bool _verified = false;
  bool _registered = false;

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
    if (_dbg.length > 5) _dbg.removeAt(0);
    onSendDebug?.call(_dbg.join(' | '));
  }

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();
  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  String _cookieVal(String name) {
    final m = RegExp('$name=([^;]+)').firstMatch(_cookie);
    return m?.group(1)?.trim() ?? '';
  }

  // ================= 连接（带 baseinfo） =================
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
    _verified = false;
    _registered = false;

    _cookie = HuyaLoginManager().cookie;
    _loginUid = int.tryParse(_cookieVal('yyuid')) ??
        (int.tryParse(_cookieVal('udb_uid')) ?? 0);
    _guid = _cookieVal('guid');
    _token = _cookieVal('udb_biztoken');

    onStatus?.call('弹幕连接中…');

    // 构建 baseinfo（WSConnectParaInfo Base64）
    final baseinfo = _buildBaseinfo();

    final endpoints = [
      'wss://wsapi.huya.com/?baseinfo=$baseinfo',
      'wss://cdnws.api.huya.com/?baseinfo=$baseinfo',
    ];

    WebSocket? ws;
    for (var i = 0; i < endpoints.length; i++) {
      if (_closed) return;
      final ep = endpoints[(_endpointIndex + i) % endpoints.length];
      try {
        ws = await WebSocket.connect(ep, headers: {
          'Origin': 'https://www.huya.com',
          'User-Agent': _ua,
        }).timeout(const Duration(seconds: 6));
        _endpointIndex = (_endpointIndex + i) % endpoints.length;
        break;
      } catch (_) {}
    }
    if (ws == null) {
      onStatus?.call('弹幕连接失败');
      _scheduleReconnect();
      return;
    }
    _ws = ws;
    onStatus?.call('弹幕已连接，认证中…');
    ws.listen(_onData, onDone: _onDone, onError: (_) => _onDone(), cancelOnError: true);

    // 1. VerifyCookie（cmd=10）
    _send(_buildVerifyCookie());

    _heartTimer?.cancel();
    _heartTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }

  /// 构建 baseinfo（WSConnectParaInfo Base64 编码）
  String _buildBaseinfo() {
    final info = _TarsWriter();
    info.writeInt(0, _loginUid); // lUid
    info.writeString(1, _guid); // sGuid
    info.writeString(2, 'webh5&1.0.0&websocket'); // sUA
    info.writeString(3, 'HUYA'); // sAppSrc
    info.writeString(4, _cookie); // sCookie

    // mCustomHeaders: map<string,string>
    final headers = _TarsWriter();
    headers.writeString(0, 'HUYA_NET');
    headers.writeString(1, '0');
    info.writeMap(5, {'HUYA_NET': '0'});

    return base64Encode(info.toBytes());
  }

  Uint8List _buildVerifyCookie() {
    final req = _TarsWriter();
    req.writeInt(0, _loginUid); // lUid
    req.writeString(1, 'webh5&1.0.0&websocket'); // sUA
    req.writeString(2, _cookie); // sCookie
    req.writeString(3, _guid); // sGuid
    req.writeInt(4, 1); // bAutoRegisterUid
    req.writeString(5, 'HUYA'); // sAppSrc

    final cmd = _TarsWriter();
    cmd.writeInt(0, 10); // EWSCmdC2S_VerifyCookieReq
    cmd.writeBytes(1, req.toBytes()); // vData
    cmd.writeInt(2, ++_reqId); // lRequestId
    return cmd.toBytes();
  }

  Uint8List _buildRegisterGroup() {
    final req = _TarsWriter();
    req.writeStringList(0, ['live:$_ayyuid']); // vGroupId
    req.writeString(1, ''); // sToken

    final cmd = _TarsWriter();
    cmd.writeInt(0, 16); // EWSCmdC2S_RegisterGroupReq
    cmd.writeBytes(1, req.toBytes());
    cmd.writeInt(2, ++_reqId);
    return cmd.toBytes();
  }

  void _sendHeartbeat() {
    final cmd = _TarsWriter();
    cmd.writeInt(0, 20); // EWSCmdC2S_HeartBeatReq
    cmd.writeBytes(1, const []);
    _send(cmd.toBytes());
  }

  // ================= 发送弹幕（servant=""） =================
  Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0 || _ws == null) return false;
    if (!_verified || !_registered) {
      _dbgPush('未认证/未注册，等待…');
      return false;
    }
    try {
      _pendingDanmaku = text;

      // 构建 UserId
      final user = _TarsWriter();
      user.writeInt(0, _loginUid);
      user.writeString(1, _guid);
      user.writeString(2, _token);
      user.writeString(3, 'webh5&1.0.0&websocket');
      user.writeString(4, _cookie);
      user.writeInt(5, 0);
      user.writeString(6, '');
      user.writeString(7, '');

      // ContentFormat
      final cf = _TarsWriter();
      cf.writeInt(0, -1); // iFontColor
      cf.writeInt(1, 4); // iFontSize
      cf.writeInt(2, 0); // iPopupStyle
      cf.writeInt(3, -1); // iNickNameFontColor
      cf.writeInt(4, -1); // iDarkFontColor
      cf.writeInt(5, -1); // iDarkNickNameFontColor

      // BulletFormat
      final bf = _TarsWriter();
      bf.writeInt(0, -1); // iFontColor
      bf.writeInt(1, 4); // iFontSize
      bf.writeInt(2, 0); // iTextSpeed
      bf.writeInt(3, 1); // iTransitionType (1=滚动)
      bf.writeInt(4, 0); // iPopupStyle
      // tag 5-8 省略（默认值）

      // SendMessageReq
      final req = _TarsWriter();
      req.writeStruct(0, user); // tUserId
      req.writeInt(1, 0); // lTid (顶级频道=0)
      req.writeInt(2, 0); // lSid (子频道=0)
      req.writeString(3, text.replaceAll('\n', ' ')); // sContent
      req.writeInt(4, 0); // iShowMode
      req.writeStruct(5, cf); // tFormat
      req.writeStruct(6, bf); // tBulletFormat
      // tag 7: vAtSomeone 省略
      req.writeInt(8, _ayyuid); // lPid = 主播UID（必需！）
      // tag 9: vTagInfo 省略
      // tag 10: tSenceFormat 省略
      req.writeInt(11, 0); // iMessageMode

      // WUP 信封（servant=""，func="sendMessage"）
      final wup = _TarsWriter();
      wup.writeInt(1, 3); // iVersion
      wup.writeInt(2, 0); // cPacketType
      wup.writeInt(3, 0); // iMessageType
      wup.writeInt(4, ++_reqId); // iRequestId
      wup.writeString(5, ''); // sServantName = 空字符串！
      wup.writeString(6, 'sendMessage'); // sFuncName

      // sBuffer: 内层 map<tag0="tReq" → req bytes>
      final inner = _TarsWriter();
      inner.writeString(0, 'tReq');
      inner.writeBytes(1, req.toBytes());
      wup.writeBytes(7, inner.toBytes()); // sBuffer

      // WebSocketCommand
      final cmd = _TarsWriter();
      cmd.writeInt(0, 3); // EWSCmd_WupReq = 3
      cmd.writeBytes(1, wup.toBytes()); // vData
      cmd.writeInt(2, _reqId); // lRequestId

      _send(cmd.toBytes());
      _dbgPush('发送"${text.substring(0, text.length > 10 ? 10 : text.length)}…" reqId=$_reqId');
      return true;
    } catch (e) {
      _dbgPush('发送异常: $e');
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_closed) {
        _endpointIndex = (_endpointIndex + 1) % 2;
        connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid);
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

  // ================= 收包 =================
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
        onStatus?.call('收包$_recvCount cmd=$cmdType (无数据)');
        return;
      }
      final payload = Uint8List.fromList(vData.map((e) => (e as int) & 0xFF).toList());

      switch (cmdType) {
        case 11: // VerifyCookieRsp
          _handleVerifyRsp(payload);
          break;
        case 17: // RegisterGroupRsp
          _handleRegisterRsp(payload);
          break;
        case 21: // HeartBeatRsp
          break;
        case 4: // WupRsp
          _handleWupRsp(payload);
          break;
        case 22: // MsgPushReq_V2
          _handleMsgPush(payload);
          break;
      }
      onStatus?.call('收包$_recvCount cmd=$cmdType');
    } catch (_) {}
  }

  void _handleVerifyRsp(Uint8List payload) {
    try {
      final f = _TarsReader(payload).readFields();
      final iValidate = f[0] is int ? f[0] as int : -1;
      _dbgPush('Verify iValidate=$iValidate');
      if (iValidate == 0) {
        _verified = true;
        // 认证成功后注册组
        _send(_buildRegisterGroup());
      }
    } catch (_) {}
  }

  void _handleRegisterRsp(Uint8List payload) {
    try {
      final f = _TarsReader(payload).readFields();
      final iResCode = f[0] is int ? f[0] as int : -1;
      _dbgPush('Register iResCode=$iResCode');
      if (iResCode == 0) {
        _registered = true;
        _dbgPush('就绪，可发弹幕 ✔');
      }
    } catch (_) {}
  }

  void _handleWupRsp(Uint8List payload) {
    try {
      final f = _TarsReader(payload).readFields();
      final servant = '${f[5] ?? ''}';
      final func = '${f[6] ?? ''}';
      final sBuffer = f[7];
      int ret = -99;
      if (sBuffer is List) {
        final inner = _TarsReader(Uint8List.fromList(
                sBuffer.map((e) => (e as int) & 0xFF).toList()))
            .readFields();
        // inner map: tag 0 -> key, tag 1 -> value bytes
        final valBytes = inner[1];
        if (valBytes is List) {
          final rsp = _TarsReader(Uint8List.fromList(
                  valBytes.map((e) => (e as int) & 0xFF).toList()))
              .readFields();
          ret = rsp[0] is int ? rsp[0] as int : -99;
        }
      }
      _dbgPush('WupRsp $func iRet=$ret');
      if (func == 'sendMessage') {
        if (ret == 0) {
          _dbgPush('发送成功 ✔');
        } else {
          _dbgPush('发送失败 iRet=$ret');
        }
      }
    } catch (e) {
      _dbgPush('WupRsp 解析异常: $e');
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
        if (msg is List && uri == 1400) {
          _decodeDanmaku(msg.map((e) => (e as int) & 0xFF).toList());
        }
      }
    } catch (_) {}
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

  void writeMap(int tag, Map<String, String> entries) {
    _head(tag, 8);
    _intValue(entries.length);
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

  int _readValueInt() {
    final t = _byte();
    switch (t) {
      case 0: return _readIntN(1);
      case 1: return _readIntN(2);
      case 2: return _readIntN(4);
      case 3: return _readIntN(8);
      case 12: return 0;
      default: throw FormatException('tars: not an int, type=$t');
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
      case 0: return _readIntN(1);
      case 1: return _readIntN(2);
      case 2: return _readIntN(4);
      case 3: return _readIntN(8);
      case 12: return 0;
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
