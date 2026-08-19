import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// 弹幕消息
class DanmakuMessage {
  final String nickname;
  final String content;
  final int fontColor;
  DanmakuMessage({required this.nickname, required this.content, this.fontColor = 0xFFFFFFFF});
}

/// 虎牙弹幕客户端
/// 多变体注册探测：cmd(0/1) × UA(webh5/lanmu)，收到任意回包即锁定；
/// 心跳带 tid/sid/pid；状态实时回报参数便于诊断。
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  static const _endpoints = [
    'wss://wsapi.huya.com/',
    'wss://cdnws.api.huya.com/',
  ];

  /// 注册包变体：[iCmdType, sUA]
  static const _variants = [
    [0, 'webh5&0.1.0&websocket'],
    [1, 'webh5&0.1.0&websocket'],
    [0, 'huya_lanmu_web_2101'],
    [1, 'huya_lanmu_web_2101'],
  ];

  WebSocket? _ws;
  Timer? _heartTimer;
  Timer? _probeTimer;
  Timer? _idleTimer;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _gotFrame = false;
  int _recvCount = 0;
  int _probeStep = 0;
  int _topSid = 0;
  int _subSid = 0;
  int _ayyuid = 0;
  int _uid = 0;

  void Function(String)? onStatus;

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();

  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  Future<int> _fetchAnonymousUid() async {
    try {
      final res = await http
          .post(
            Uri.parse('https://udblgn.huya.com/web/anonymousLogin'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _ua,
              'Origin': 'https://www.huya.com',
              'Referer': 'https://www.huya.com/',
            },
            body: jsonEncode({
              'appId': 5002,
              'byPass': 3,
              'context': '',
              'version': '2.4',
              'data': {},
            }),
          )
          .timeout(const Duration(seconds: 6));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final uid = (j['data'] as Map<String, dynamic>?)?['uid'];
      if (uid is int) return uid;
      if (uid is String) return int.tryParse(uid) ?? 0;
      if (uid is double) return uid.toInt();
    } catch (e) {
      print('DANMAKU anonymous uid failed: $e');
    }
    return 0;
  }

  Future<void> connect({required int topSid, required int subSid, int uid = 0}) async {
    _closed = false;
    _recvCount = 0;
    _gotFrame = false;
    _probeStep = 0;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid;
    var realUid = uid;
    if (realUid <= 0) realUid = await _fetchAnonymousUid();
    if (realUid <= 0) {
      realUid = 1400000000000 + (DateTime.now().millisecondsSinceEpoch % 10000000000);
    }
    _uid = realUid;
    print('DANMAKU connect topSid=$topSid subSid=$subSid ayyuid=$uid anon=$realUid');

    onStatus?.call('弹幕连接中…');
    WebSocket? ws;
    for (final ep in _endpoints) {
      if (_closed) return;
      try {
        ws = await WebSocket.connect(
          ep,
          headers: {
            'Origin': 'https://www.huya.com',
            'User-Agent': _ua,
            'Cookie': 'huya_ua=webh5&0.1.0&websocket',
          },
        ).timeout(const Duration(seconds: 6));
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

    _sendRegisterVariant();
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (_gotFrame) {
        _probeTimer?.cancel();
        return;
      }
      if (_probeStep < _variants.length - 1) {
        _probeStep++;
        onStatus?.call('注册尝试${_probeStep + 1}/${_variants.length} ts=$_topSid ss=$_subSid uid=$_uid');
        _sendRegisterVariant();
      } else {
        onStatus?.call('注册无响应 ts=$_topSid ss=$_subSid uid=$_uid');
      }
    });

    _heartTimer?.cancel();
    _heartTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _send(_buildHeartbeat());
    });
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _sendRegisterVariant();
      _send(_buildHeartbeat());
    });
  }

  void _sendRegisterVariant() {
    final v = _variants[_probeStep.clamp(0, _variants.length - 1)];
    _send(_buildRegister(v[0] as int, v[1] as String));
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_closed) {
        onStatus?.call('弹幕断线重连…');
        connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid);
      }
    });
  }

  void _onDone() {
    _heartTimer?.cancel();
    _idleTimer?.cancel();
    _probeTimer?.cancel();
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
    _idleTimer?.cancel();
    _probeTimer?.cancel();
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
      _gotFrame = true;
      onStatus?.call('弹幕已连接，收包$_recvCount');
      final bytes = Uint8List.fromList((data as List).cast<int>());
      final r = _TarsReader(bytes);
      final fields = r.readFields();
      final cmd = fields[0];
      if (cmd == 6) {
        final push = fields[1];
        if (push is Map<int, Object?>) {
          final vData = push[3];
          if (vData is List) {
            final nr = _TarsReader(
                Uint8List.fromList(vData.map((e) => (e as int) & 0xFF).toList()));
            final nf = nr.readFields();
            final msgs = <DanmakuMessage>[];
            _scan(nf, msgs);
            for (final m in msgs) {
              _controller.add(m);
            }
            if (msgs.isNotEmpty) onStatus?.call('弹幕已接收');
          }
        }
      }
    } catch (_) {}
  }

  void _scan(Object? node, List<DanmakuMessage> out) {
    if (node is Map<int, Object?>) {
      final c = node[3];
      if (c is String && c.isNotEmpty) {
        final sender = node[0];
        var nick = '';
        if (sender is Map<int, Object?>) nick = '${sender[2] ?? ''}';
        out.add(DanmakuMessage(nickname: nick, content: c));
      }
      for (final v in node.values) {
        _scan(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        _scan(v, out);
      }
    }
  }

  // ================= 发包 =================
  Uint8List _buildRegister(int cmdType, String sUA) {
    final groups = <String>{};
    if (_topSid > 0) groups.add('live://$_topSid');
    if (_subSid > 0) groups.add('chat:$_subSid');
    if (_ayyuid > 0) {
      groups.add('live:$_ayyuid');
      groups.add('chat:$_ayyuid');
    }

    final user = _TarsWriter();
    user.writeInt(0, _uid);
    user.writeString(1, '');
    user.writeString(2, '');

    final payload = _TarsWriter();
    payload.writeStruct(0, user);
    payload.writeStringList(1, groups.toList());
    payload.writeString(2, sUA);

    final cmd = _TarsWriter();
    cmd.writeInt(0, cmdType);
    cmd.writeStruct(1, payload);
    return cmd.toBytes();
  }

  /// 心跳：HuyaHeartBeatData { lTid, lSid, lPid }
  Uint8List _buildHeartbeat() {
    final beat = _TarsWriter();
    beat.writeInt(0, _topSid);
    beat.writeInt(1, _subSid);
    beat.writeInt(2, _uid);
    final cmd = _TarsWriter();
    cmd.writeInt(0, 2); // C2S_HeartBeatReq
    cmd.writeStruct(1, beat);
    return cmd.toBytes();
  }

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
    _b.addByte(0x0C);
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
      if (type == 12) return m;
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
