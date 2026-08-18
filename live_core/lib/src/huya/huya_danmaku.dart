import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 弹幕消息（字段名对齐 UI 层的 danmaku_view.dart）
class DanmakuMessage {
  final String nickname;
  final String content;
  final int fontColor;
  DanmakuMessage({required this.nickname, required this.content, this.fontColor = 0xFFFFFFFF});
}

/// 虎牙弹幕客户端（WebSocket + Tars，对齐 dtv_mobile / pure_live）
class HuyaDanmakuClient {
  WebSocket? _ws;
  Timer? _heartTimer;
  Timer? _idleTimer;
  bool _closed = false;
  Uint8List _registerPayload = Uint8List(0);

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();

  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  Future<void> connect({required int topSid, required int subSid, int uid = 0}) async {
    _closed = false;
    _registerPayload = _buildRegister(topSid, subSid, uid);
    try {
      _ws = await WebSocket.connect(
        'wss://cdnws.api.huya.com/',
        headers: {
          'Origin': 'https://www.huya.com',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      print('DANMAKU connect failed: $e');
      return;
    }
    _ws!.listen(_onData, onDone: _onDone, onError: (_) => _onDone(), cancelOnError: true);
    _send(_registerPayload);

    // 心跳 20s（dtv 同款）
    _heartTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _send(_buildHeartbeat());
    });
    // 空闲重发注册包（dtv: idle re-send subscribe）
    _idleTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _send(_registerPayload);
    });
  }

  void _send(List<int> data) {
    try {
      if (_ws != null && _ws!.readyState == WebSocket.open) {
        _ws!.add(data);
      }
    } catch (_) {}
  }

  void _onDone() {
    if (_closed) return;
    _closed = true;
    _heartTimer?.cancel();
    _idleTimer?.cancel();
  }

  void disconnect() {
    _closed = true;
    _heartTimer?.cancel();
    _idleTimer?.cancel();
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  // ================= 收包解析 =================
  void _onData(dynamic data) {
    try {
      final bytes = Uint8List.fromList((data as List).cast<int>());
      final r = _TarsReader(bytes);
      final fields = r.readFields();
      final cmd = fields[0];
      if (cmd == 6) {
        // S2C_MsgPushReq
        final push = fields[1];
        if (push is Map<int, Object?>) {
          final uri = '${push[2]}';
          final vData = push[3];
          if (uri.contains('message_notice') && vData is List) {
            final nr = _TarsReader(
                Uint8List.fromList(vData.map((e) => (e as int) & 0xFF).toList()));
            final nf = nr.readFields();
            final sender = nf[0];
            final content = nf[3];
            if (content is String && content.isNotEmpty) {
              var nick = '';
              if (sender is Map<int, Object?>) nick = '${sender[2] ?? ''}';
              // 对齐 UI 层字段名：nickname / fontColor
              _controller.add(DanmakuMessage(
                nickname: nick, 
                content: content, 
                fontColor: 0xFFFFFFFF,
              ));
            }
          }
        }
      }
    } catch (_) {}
  }

  // ================= 发包构造 =================
  Uint8List _buildRegister(int topSid, int subSid, int uid) {
    final user = _TarsWriter();
    user.writeInt(0, uid); // lUid
    user.writeString(1, ''); // sGuid
    user.writeString(2, ''); // sToken

    final payload = _TarsWriter();
    payload.writeStruct(0, user); // stUserId
    payload.writeStringList(1, ['live://$topSid', 'chat:$subSid']); // vGroupId
    payload.writeString(2, 'webh5&0.1.0&websocket'); // sUA（dtv 同款）

    final cmd = _TarsWriter();
    cmd.writeInt(0, 0); // C2S_RegisterGroupReq
    cmd.writeStruct(1, payload);
    return cmd.toBytes();
  }

  Uint8List _buildHeartbeat() {
    final cmd = _TarsWriter();
    cmd.writeInt(0, 2); // C2S_HeartBeatReq
    cmd.writeStruct(1, _TarsWriter());
    return cmd.toBytes();
  }

  /// 发送弹幕（需要登录，未登录时由 controller 拦截）
  void sendDanmaku(String text) {
    print('DANMAKU send (login required): $text');
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
    _b.addByte(t);
    _add(v, [1, 2, 4, 8][t]);
  }

  void writeInt(int tag, int v) {
    final t = _intType(v);
    _head(tag, t);
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

  void writeStruct(int tag, _TarsWriter inner) {
    _head(tag, 10);
    _b.add(inner._b.toBytes());
    _b.addByte(0x0C); // struct end
  }

  void writeStringList(int tag, List<String> items) {
    _head(tag, 9);
    _intValue(items.length);
    for (final s in items) {
      writeString(0, s);
    }
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
      default:
        throw const FormatException('tars: not an int');
    }
  }

  Map<int, Object?> readFields() {
    final m = <int, Object?>{};
    while (hasMore) {
      final h = _byte();
      final type = h & 0x0F;
      if (type == 12) return m; // struct end
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
      case 10:
        return readFields();
      default:
        throw FormatException('tars: unknown type $type');
    }
  }
}
