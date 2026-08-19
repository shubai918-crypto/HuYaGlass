import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'huya_login.dart';

class DanmakuMessage {
  final String nickname;
  final String content;
  final int fontColor;
  DanmakuMessage({required this.nickname, required this.content, this.fontColor = 0xFFFFFFFF});
}

class HuyaDanmakuClient {
  static const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  static const _endpoints = ['wss://wsapi.huya.com', 'wss://cdnws.api.huya.com'];

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
  String _roomIdStr = '';

  void Function(String)? onStatus;
  void Function(int)? onPopularity;

  final StreamController<DanmakuMessage> _controller = StreamController<DanmakuMessage>.broadcast();
  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  Future<void> connect({required int topSid, required int subSid, int uid = 0, String roomIdStr = ''}) async {
    _closed = false;
    _recvCount = 0;
    _lastType = -1;
    _lastUri = -1;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid > 0 ? uid : topSid;
    _roomIdStr = roomIdStr;

    onStatus?.call('弹幕连接中…');
    WebSocket? ws;
    for (var i = 0; i < _endpoints.length; i++) {
      if (_closed) return;
      final ep = _endpoints[(_endpointIndex + i) % _endpoints.length];
      try {
        ws = await WebSocket.connect(ep, headers: {'Origin': 'https://www.huya.com', 'User-Agent': _ua}).timeout(const Duration(seconds: 6));
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
    });

    _heartTimer?.cancel();
    _heartTimer = Timer.periodic(const Duration(seconds: 60), (_) => _sendHeartbeat());
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

  void _sendHeartbeat() {
    final command = _TarsWriter();
    command.writeInt(0, 20);
    command.writeBytes(1, const []);
    _send(command.toBytes());
  }

  /// 真实发送弹幕（虎牙网页端同款 HTTP POST 接口）
  Future<bool> sendDanmaku(String text) async {
    final cookie = HuyaLoginManager().cookie;
    if (cookie.isEmpty) return false;

    try {
      final random = Random();
      final uuid = '${random.nextInt(100000000)}${DateTime.now().millisecondsSinceEpoch}';
      final rid = _roomIdStr.isNotEmpty ? _roomIdStr : _ayyuid.toString();

      final response = await http.post(
        Uri.parse('https://tip.huya.com/cache.php?m=Live&do=sendContent'),
        headers: {
          'Cookie': cookie,
          'User-Agent': _ua,
          'Referer': 'https://www.huya.com/',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'content': text,
          'rid': rid,
          'from': 'hs',
          'uuid': uuid,
        },
      ).timeout(const Duration(seconds: 5));

      print('DANMAKU send response: ${response.statusCode} ${response.body}');
      // 虎牙成功返回通常包含 "status":200 或 "status":0
      return response.statusCode == 200 && (response.body.contains('"status":200') || response.body.contains('"status":0') || response.body.contains('"code":0'));
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
        connect(topSid: _topSid, subSid: _subSid, uid: _ayyuid, roomIdStr: _roomIdStr);
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
    try { _ws?.close(); } catch (_) {}
    _ws = null;
  }

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
        final pr = _TarsReader(Uint8List.fromList(payload.map((e) => (e as int) & 0xFF).toList()));
        if (type == 7) {
          final pf = pr.readFields();
          final uri = pf[1] is int ? pf[1] as int : 0;
          _lastUri = uri;
          final msg = pf[2];
          if (msg is List) _decodePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
        } else if (type == 22) {
          final pf = pr.readFields();
          final items = pf[1];
          if (items is List) {
            for (final item in items) {
              if (item is Map<int, Object?>) {
                final uri = item[0] is int ? item[0] as int : 0;
                _lastUri = uri;
                final msg = item[1];
                if (msg is List) _decodePush(uri, msg.map((e) => (e as int) & 0xFF).toList());
              }
            }
          }
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
          final sender = fields[0] is Map<int, Object?> ? fields[0] as Map<int, Object?> : null;
          final nick = '${sender?[2] ?? ''}';
          final bf = fields[6] is Map<int, Object?> ? fields[6] as Map<int, Object?> : null;
          final color = bf?[0] is int ? bf![0] as int : 0;
          _controller.add(DanmakuMessage(nickname: nick, content: content, fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000)));
          onStatus?.call('弹幕已接收');
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

// ================= Tars 编码/解码 (保持不变) =================
class _TarsWriter {
  final BytesBuilder _b = BytesBuilder();
  void _head(int tag, int type) { if (tag < 15) { _b.addByte((tag << 4) | type); } else { _b.addByte(0xF0 | type); _b.addByte(tag); } }
  int _intType(int v) { if (v == 0) return 12; if (v >= -128 && v <= 127) return 0; if (v >= -32768 && v <= 32767) return 1; if (v >= -2147483648 && v <= 2147483647) return 2; return 3; }
  void _add(int v, int n) { for (var i = n - 1; i >= 0; i--) { _b.addByte((v >> (8 * i)) & 0xFF); } }
  void _intValue(int v) { final t = _intType(v); if (t == 12) return; _b.addByte(t); _add(v, [1, 2, 4, 8][t]); }
  void writeInt(int tag, int v) { final t = _intType(v); _head(tag, t); if (t == 12) return; _add(v, [1, 2, 4, 8][t]); }
  void writeString(int tag, String s) { final b = utf8.encode(s); if (b.length < 256) { _head(tag, 6); _b.addByte(b.length); } else { _head(tag, 7); _add(b.length, 4); } _b.add(b); }
  void writeStringList(int tag, List<String> items) { _head(tag, 9); _intValue(items.length); for (final s in items) { writeString(0, s); } }
  void writeBytes(int tag, List<int> bytes) { _head(tag, 13); _head(0, 0); _intValue(bytes.length); _b.add(bytes); }
  void writeMapStart(int tag, int size) { _head(tag, 8); _intValue(size); }
  Uint8List toBytes() => Uint8List.fromList(_b.toBytes());
}

class _TarsReader {
  final Uint8List _d; int _pos = 0; _TarsReader(this._d);
  bool get hasMore => _pos < _d.length; int _byte() => _d[_pos++];
  int _readIntN(int n) { var v = 0; for (var i = 0; i < n; i++) { v = (v << 8) | _d[_pos++]; } final shift = 64 - 8 * n; return (v << shift) >> shift; }
  int _readValueInt() { final t = _byte(); switch (t) { case 0: return _readIntN(1); case 1: return _readIntN(2); case 2: return _readIntN(4); case 3: return _readIntN(8); case 12: return 0; default: throw FormatException('tars: not an int'); } }
  Map<int, Object?> readFields() { final m = <int, Object?>{}; while (hasMore) { final h = _byte(); final type = h & 0x0F; if (type == 11) return m; var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); m[tag] = _readValue(type); } return m; }
  Object? _readValue(int type) { switch (type) { case 0: return _readIntN(1); case 1: return _readIntN(2); case 2: return _readIntN(4); case 3: return _readIntN(8); case 12: return 0; case 4: final v = ByteData.sublistView(_d, _pos, _pos + 4).getFloat32(0); _pos += 4; return v; case 5: final v = ByteData.sublistView(_d, _pos, _pos + 8).getFloat64(0); _pos += 8; return v; case 6: final n = _byte(); final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true); _pos += n; return s; case 7: final n = _readIntN(4); final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true); _pos += n; return s; case 13: _byte(); final n = _readValueInt(); final bytes = _d.sublist(_pos, _pos + n); _pos += n; return bytes; case 9: final size = _readValueInt(); final list = <Object?>[]; for (var i = 0; i < size; i++) { final h = _byte(); var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); list.add(_readValue(h & 0x0F)); } return list; case 8: final size = _readValueInt(); final list = <Object?>[]; for (var i = 0; i < size * 2; i++) { final h = _byte(); var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); list.add(_readValue(h & 0x0F)); } return list; case 10: return readFields(); default: throw FormatException('tars: unknown type $type'); } }
}
