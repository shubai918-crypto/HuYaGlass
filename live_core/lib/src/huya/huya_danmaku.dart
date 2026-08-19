import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// 弹幕消息
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

/// 虎牙弹幕客户端
/// 协议对齐 pure_live/core/danmaku/huya_danmaku.dart：
/// - 节点 wss://wsapi.huya.com（cdnws 兜底）
/// - 注册 cmd=16：['live:$uid', 'chat:$uid'] + ''
/// - 心跳 cmd=20：空字节包，60s 间隔
/// - 收包：外层 type=7(HYPushMessage) / 22(HYPushMessageV2 批量)
///   uri=1400 聊天弹幕；uri=8006 人气值
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

  /// 状态回报（连接/收包/诊断）
  void Function(String)? onStatus;

  /// 人气值回报（uri=8006 实时推送）
  void Function(int)? onPopularity;

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();

  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  // ================= 连接 =================
  Future<void> connect({required int topSid, required int subSid, int uid = 0}) async {
    _closed = false;
    _recvCount = 0;
    _lastType = -1;
    _lastUri = -1;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid > 0 ? uid : topSid;
    print('DANMAKU connect ayyuid=$_ayyuid topSid=$_topSid subSid=$_subSid');

    onStatus?.call('弹幕连接中…');
    WebSocket? ws;
    for (var i = 0; i < _endpoints.length; i++) {
      if (_closed) return;
      final ep = _endpoints[(_endpointIndex + i) % _endpoints.length];
      try {
        ws = await WebSocket.connect(
          ep,
          headers: {
            'Origin': 'https://www.huya.com',
            'User-Agent': _ua,
          },
        ).timeout(const Duration(seconds: 6));
        _endpointIndex = (_endpointIndex + i) % _endpoints.length;
        print('DANMAKU connected: $ep');
        break;
      } catch (e) {
        print('DANMAKU endpoint failed: $ep -> $e');
      }
    }
    if (ws == null) {
      onStatus?.call('弹幕连接失败');
      _scheduleReconnect();
      return;
    }
    _ws = ws;
    onStatus?.call('弹幕已连接，注册中…');
    ws.listen(_onData, onDone: _onDone, onError: (_) => _onDone(), cancelOnError: true);

    // pure_live 同款注册：live:$uid / chat:$uid
    _send(_buildRegister(_ayyuid, _ayyuid));
    // 1 秒后补发 topSid/subSid 版本（双保险）
    _secondRegTimer?.cancel();
    _secondRegTimer = Timer(const Duration(seconds: 1), () {
      if (_topSid > 0) _send(_buildRegister(_topSid, _subSid));
    });

    // 心跳：cmd=20 空包，60s
    _heartTimer?.cancel();
    _heartTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendHeartbeat();
    });
  }

  // ================= 发包 =================
  /// pure_live getJoinData 逐行对齐
  Uint8List _buildRegister(int liveId, int chatId) {
    final group = _TarsWriter();
    group.writeStringList(0, ['live:$liveId', 'chat:$chatId']);
    group.writeString(1, '');
    final command = _TarsWriter();
    command.writeInt(0, 16); // EWSCmdC2S_RegisterGroupReq
    command.writeBytes(1, group.toBytes());
    return command.toBytes();
  }

  /// pure_live heartbeatData 逐行对齐
  void _sendHeartbeat() {
    final command = _TarsWriter();
    command.writeInt(0, 20); // EWSCmdC2S_HeartBeatReq
    command.writeBytes(1, const []);
    _send(command.toBytes());
  }

  /// 真实发送弹幕（网页端同款 WUP liveui/sendMessage，需登录 Cookie 会话）
  Future<bool> sendDanmaku(String text) async {
    if (_ws == null || _ws!.readyState != WebSocket.open) return false;
    try {
      final req = _TarsWriter();
      req.writeInt(0, _topSid); // lTid
      req.writeInt(1, _subSid); // lSid
      req.writeInt(2, _ayyuid); // lPid
      req.writeString(3, text); // sContent
      req.writeInt(4, 0); // iShowMode

      final map = _TarsWriter();
      map.writeMapStart(0, 1);
      map.writeString(0, 'sendMessage');
      map.writeBytes(1, req.toBytes());

      final wup = _TarsWriter();
      wup.writeInt(1, 3); // iVersion
      wup.writeInt(2, 0); // cPacketType
      wup.writeInt(3, 0); // iMessageType
      wup.writeInt(4, ++_reqId); // iRequestId
      wup.writeString(5, 'liveui'); // sServantName
      wup.writeString(6, 'sendMessage'); // sFuncName
      wup.writeBytes(7, map.toBytes()); // sBuffer

      _send(wup.toBytes());
      return true;
    } catch (e) {
      print('DANMAKU send error: $e');
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_closed) {
        _endpointIndex = (_endpointIndex + 1) % _endpoints.length;
        onStatus?.call('弹幕断线重连…');
        connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid);
      }
    });
  }

  void _onDone() {
    _heartTimer?.cancel();
    _secondRegTimer?.cancel();
    if (_closed) return;
    onStatus?.call('弹幕断线，准备重连…');
    _scheduleReconnect();
  }

  void _send(List<int> data) {
    try {
      if (_ws != null && _ws!.readyState == WebSocket.open) {
        _ws!.add(data);
      }
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

  // ================= 收包（pure_live decodeMessage 对齐） =================
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
          // HYPushMessage: pushType@0 uri@1 msg@2 protocolType@3
          final pf = pr.readFields();
          final uri = pf[1] is int ? pf[1] as int : 0;
          _lastUri = uri;
          final msg = pf[2];
          if (msg is List) {
            _decodePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
          }
        } else if (type == 22) {
          // HYPushMessageV2: groupId@0 items@1
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
        }
      }
      onStatus?.call('收包$_recvCount type=$_lastType uri=$_lastUri');
    } catch (e) {
      print('DANMAKU decode error: $e');
    }
  }

  void _decodePush(int uri, List<int> payload) {
    if (uri == 1400) {
      // HYMessage: userInfo@0 content@3 bulletFormat@6
      try {
        final reader = _TarsReader(Uint8List.fromList(payload));
        final fields = reader.readFields();
        final content = fields[3];
        if (content is String && content.isNotEmpty) {
          final sender = fields[0] is Map<int, Object?> ? fields[0] as Map<int, Object?> : null;
          final nick = '${sender?[2] ?? ''}';
          final bf = fields[6] is Map<int, Object?> ? fields[6] as Map<int, Object?> : null;
          final color = bf?[0] is int ? bf![0] as int : 0;
          _controller.add(DanmakuMessage(
            nickname: nick,
            content: content,
            fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000),
          ));
          onStatus?.call('弹幕已接收');
        }
      } catch (e) {
        print('DANMAKU parse 1400 error: $e');
      }
    } else if (uri == 8006) {
      // 人气值推送
      try {
        final reader = _TarsReader(Uint8List.fromList(payload));
        final fields = reader.readFields();
        final v = fields[0] is int ? fields[0] as int : 0;
        if (v > 0) onPopularity?.call(v);
      } catch (_) {}
    }
  }
}

// ================= 极简 Tars 编码 =================
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
    if (v == 0) return 12; // ZERO_TAG
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
    final b = s.codeUnits.isEmpty ? <int>[] : _utf8(s);
    if (b.length < 256) {
      _head(tag, 6);
      _b.addByte(b.length);
    } else {
      _head(tag, 7);
      _add(b.length, 4);
    }
    _b.add(b);
  }

  List<int> _utf8(String s) {
    // 避免引入 dart:convert，用 Uri 编码转 UTF-8
    final encoded = Uri.encodeToByteArray(s);
    return encoded;
  }

  void writeStringList(int tag, List<String> items) {
    _head(tag, 9);
    _intValue(items.length);
    for (final s in items) {
      writeString(0, s);
    }
  }

  /// 字节向量 = Tars SIMPLE_LIST(13)
  void writeBytes(int tag, List<int> bytes) {
    _head(tag, 13);
    _head(0, 0);
    _intValue(bytes.length);
    _b.add(bytes);
  }

  void writeMapStart(int tag, int size) {
    _head(tag, 8);
    _intValue(size);
  }

  Uint8List toBytes() => Uint8List.fromList(_b.toBytes());
}

// ================= 极简 Tars 解码 =================
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
      if (type == 11) return m; // STRUCT_END
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
        final s = _decodeUtf8(_d.sublist(_pos, _pos + n));
        _pos += n;
        return s;
      case 7:
        final n = _readIntN(4);
        final s = _decodeUtf8(_d.sublist(_pos, _pos + n));
        _pos += n;
        return s;
      case 13: // SIMPLE_LIST 字节流
        _byte();
        final n = _readValueInt();
        final bytes = _d.sublist(_pos, _pos + n);
        _pos += n;
        return bytes;
      case 9: // LIST
        final size = _readValueInt();
        final list = <Object?>[];
        for (var i = 0; i < size; i++) {
          final h = _byte();
          var tag = (h >> 4) & 0x0F;
          if (tag == 15) tag = _byte();
          list.add(_readValue(h & 0x0F));
        }
        return list;
      case 8: // MAP
        final size = _readValueInt();
        final list = <Object?>[];
        for (var i = 0; i < size * 2; i++) {
          final h = _byte();
          var tag = (h >> 4) & 0x0F;
          if (tag == 15) tag = _byte();
          list.add(_readValue(h & 0x0F));
        }
        return list;
      case 10: // STRUCT
        return readFields();
      default:
        throw FormatException('tars: unknown type $type');
    }
  }

  String _decodeUtf8(List<int> bytes) {
    try {
      return Uri.decodeFull(String.fromCharCodes(bytes));
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}
