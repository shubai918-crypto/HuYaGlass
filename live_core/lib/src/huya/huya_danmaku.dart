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

/// 虎牙弹幕客户端（完全复刻网页端 WS 协议）
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

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

    // 1. 注册房间组 (16)
    _send(_buildRegister(_ayyuid, _ayyuid));
    _secondRegTimer?.cancel();
    _secondRegTimer = Timer(const Duration(seconds: 1), () {
      if (_topSid > 0) _send(_buildRegister(_topSid, _subSid));
      // 2. 验证 Cookie (10)
      if (_loginUid > 0) _send(_buildVerifyCookie());
      // 3. 网页端特有的 wsLaunch 握手 (命令字 3)
      _send(_buildWsLaunchReq());
    });

    _heartTimer?.cancel();
    _heartTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _sendHeartbeat());
  }

  Uint8List _buildRegister(int liveId, int chatId) {
    final group = _TarsWriter();
    group.writeStringList(0, ['live:$liveId', 'chat:$chatId']);
    group.writeString(1, '');
    final command = _TarsWriter();
    command.writeInt(0, 16); // EWSCmdC2S_RegisterGroupReq
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
    command.writeInt(0, 10); // EWSCmdC2S_VerifyCookieReq
    command.writeBytes(1, req.toBytes());
    return command.toBytes();
  }

  /// 网页端 wsLaunch 握手（必须在发业务 WUP 前执行）
  Uint8List _buildWsLaunchReq() {
    final dev = _TarsWriter();
    dev.writeString(0, ''); // sIMEI
    dev.writeString(1, ''); // sAPN
    dev.writeString(2, 'wifi'); // sNetType
    dev.writeString(3, _guid); // sDeviceId
    dev.writeString(4, ''); // sMId

    final req = _TarsWriter();
    req.writeInt(0, _loginUid);
    req.writeString(1, _guid);
    req.writeString(2, _cookieVal('huya_ua').isEmpty ? 'webh5&0.1.0&websocket' : _cookieVal('huya_ua'));
    req.writeString(3, 'webh5&CN&2052'); // sAppSrc
    req.writeStruct(4, dev);

    final wup = _TarsWriter();
    wup.writeInt(1, 3);
    wup.writeInt(2, 0);
    wup.writeInt(3, 0);
    wup.writeInt(4, ++_reqId);
    wup.writeString(5, 'launch');
    wup.writeString(6, 'wsLaunch');
    wup.writeBytesMap(7, {'tReq': req.toBytes()});
    return _wrapWsCmd(wup.toBytes(), 3); // EWSCmd_WupReq = 3
  }

  void _sendHeartbeat() {
    final command = _TarsWriter();
    command.writeInt(0, 20);
    command.writeBytes(1, const []);
    _send(command.toBytes());
  }

  // ================= 真实发送（WS 命令字 3） =================
  Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0 || _ws == null) return false;
    try {
      _pendingDanmaku = text;
      onSendDebug?.call('WS 发送 liveui.sendMessage (cmd=3)');
      _send(_buildWupSend(text, 'liveui'));
      // 500ms 后若没回显，补发 GameLive (App 端 servant)
      Timer(const Duration(milliseconds: 500), () {
        if (!_closed && _pendingDanmaku == text) {
          onSendDebug?.call('WS 补发 GameLive.sendMessage (cmd=3)');
          _send(_buildWupSend(text, 'GameLive'));
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// WUP(liveui/GameLive/sendMessage) —— 字段顺序严格对齐 MessageNotice
  Uint8List _buildWupSend(String text, String servant) {
    // UserId (对齐 SenderInfo)
    final user = _TarsWriter();
    user.writeInt(0, _loginUid);
    user.writeString(1, _guid);
    user.writeString(2, _token);
    user.writeInt(3, 0);
    user.writeString(4, _cookieVal('huya_ua').isEmpty ? 'webh5&0.1.0&websocket' : _cookieVal('huya_ua'));
    user.writeString(5, ''); 
    user.writeString(6, _cookie);
    user.writeString(7, ''); 

    // ContentFormat
    final cf = _TarsWriter();
    cf.writeInt(0, -1);
    cf.writeInt(1, 4);
    cf.writeInt(2, 0);
    cf.writeInt(3, -1);

    // BulletFormat
    final bf = _TarsWriter();
    bf.writeInt(0, -1); 
    bf.writeInt(1, 4);
    bf.writeInt(2, 1);
    bf.writeInt(3, 0);
    bf.writeInt(4, 0);

    // SendMessageReq (严格对齐 MessageNotice 的 tag 顺序)
    final req = _TarsWriter();
    req.writeStruct(0, user); // 0: tUserInfo
    req.writeInt(1, _topSid); // 1: lTid
    req.writeInt(2, _subSid); // 2: lSid
    req.writeString(3, text.replaceAll('\n', ' ')); // 3: sContent
    req.writeInt(4, 0); // 4: iShowMode
    req.writeStruct(5, cf); // 5: tFormat
    req.writeStruct(6, bf); // 6: tBulletFormat

    final wup = _TarsWriter();
    wup.writeInt(1, 3);
    wup.writeInt(2, 0);
    wup.writeInt(3, 0);
    wup.writeInt(4, ++_reqId);
    wup.writeString(5, servant);
    wup.writeString(6, 'sendMessage');
    wup.writeBytesMap(7, {'tReq': req.toBytes()});
    return _wrapWsCmd(wup.toBytes(), 3); // EWSCmd_WupReq = 3
  }

  Uint8List _wrapWsCmd(Uint8List wup, int cmdType) {
    final command = _TarsWriter();
    command.writeInt(0, cmdType);
    command.writeBytes(1, wup);
    command.writeInt(2, _reqId);
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
        final pr = _TarsReader(
            Uint8List.fromList(payload.map((e) => (e as int) & 0xFF).toList()));
        
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
          // EWSCmd_WupRsp (4) —— 解析 WUP 响应
          _parseWupRsp(payload);
        } else if (type == 11) {
          // VerifyCookieRsp
          try {
            final pf = pr.readFields();
            final v = pf[0] is int ? pf[0] as int : -1;
            onSendDebug?.call('VerifyCookie iValidate=$v (0=通过)');
          } catch (_) {}
        }
      }
      onStatus?.call('收包$_recvCount type=$_lastType uri=$_lastUri');
    } catch (_) {}
  }

  void _parseWupRsp(List payload) {
    try {
      final pr = _TarsReader(Uint8List.fromList(payload.map((e) => (e as int) & 0xFF).toList()));
      final wupBytes = pr.readFields()[1];
      if (wupBytes is List) {
        final wupReader = _TarsReader(Uint8List.fromList(wupBytes.map((e) => (e as int) & 0xFF).toList()));
        final wupFields = wupReader.readFields();
        final funcName = wupFields[6];
        final reqId = wupFields[4];
        final bufferMap = wupFields[7];
        int ret = -99;
        if (bufferMap is List) {
          for (var i = 0; i + 1 < bufferMap.length; i += 2) {
            if ('${bufferMap[i]}' == 'tRsp' && bufferMap[i + 1] is List) {
              final rspBytes = (bufferMap[i + 1] as List).map((e) => (e as int) & 0xFF).toList();
              final rspFields = _TarsReader(Uint8List.fromList(rspBytes)).readFields();
              ret = rspFields[0] is int ? rspFields[0] as int : -99;
            }
          }
        }
        onSendDebug?.call('WS WupRsp func=$funcName reqId=$reqId iRet=$ret');
        if (funcName == 'sendMessage' && ret == 0) {
           onSendDebug?.call('发送诊断 服务器已接受(iRet=0) ✔');
        } else if (funcName == 'sendMessage') {
           onSendDebug?.call('发送诊断 服务器拒绝(iRet=$ret)');
        }
      }
    } catch (e) {
      onSendDebug?.call('WS WupRsp 解析失败: $e');
    }
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
            onStatus?.call('弹幕发送成功 ✔');
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
