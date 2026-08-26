import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'huya_login.dart';

class DanmakuMessage {
  final String nickname;
  final String content;
  final int fontColor;
  final String avatar;
  final int uid;
  final String fansName;
  final int fansLevel;
  final int managerType; // 0=无 1=房管 2=超管
  DanmakuMessage({
    required this.nickname,
    required this.content,
    this.fontColor = 0xFFFFFFFF,
    this.avatar = '',
    this.uid = 0,
    this.fansName = '',
    this.fansLevel = 0,
    this.managerType = 0,
  });
}

/// 虎牙弹幕客户端（网页同款握手 + 历史弹幕 getRctTimedMessage）
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0';
  static const _sendHuYaUA = 'webh5&2608191804&websocket';

  static const _wsHosts = [
    'ded35397-ws.va.huya.com',
    '65cecb22-ws.va.huya.com',
    'wsapi.huya.com',
    'cdnws.api.huya.com',
  ];

  /// ★ 网页真实 cmd=33：live 组订阅（8 个扩展类型）
  static const _SUB33_LIVE =
      '060c48555941265a482632303532162030613764666161323338353538323661326330316239383562613835363639632c3c6a08000106126c6976653a31323739353231303533353731180008011893100101194f100101195110010119531001011bc31001011bc41001011bc51001011bca1001180c30010b780c8c2c36004c5c6600';

  /// ★ 网页真实 cmd=33：chat 组订阅（6211 = 历史聊天推送开关）
  static const _SUB33_CHAT =
      '060c48555941265a482632303532162030613764666161323338353538323661326330316239383562613835363639632c3c6a0800010612636861743a313237393532313035333537311800010118431001180c30010b780c8c2c36004c5c6600';

  WebSocket? _ws;
  Timer? _heartTimer;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _recvCount = 0;
  int _lastType = -1;
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

  List<String> _dynamicHosts = [];

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

  String _randHex(int n) {
    const chars = '0123456789abcdef';
    return List.generate(n, (_) => chars[Random().nextInt(16)]).join();
  }

  List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  int _indexOf(List<int> bytes, List<int> pattern) {
    for (var i = 0; i + pattern.length <= bytes.length; i++) {
      var ok = true;
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  // ================= DNS 优选 =================
  Future<List<String>> _preferredHosts() async {
    final hosts = _dynamicHosts.isNotEmpty ? _dynamicHosts : _wsHosts;
    final cost = <String, int>{};

    await Future.wait(hosts.map((h) async {
      final sw = Stopwatch()..start();
      try {
        final addrs =
            await InternetAddress.lookup(h).timeout(const Duration(seconds: 2));
        sw.stop();
        cost[h] = addrs.isNotEmpty ? sw.elapsedMilliseconds : -1;
      } catch (_) {
        cost[h] = -1;
      }
    }));

    final ok = hosts.where((h) => (cost[h] ?? -1) >= 0).toList()
      ..sort((a, b) => cost[a]! - cost[b]!);
    final bad = hosts.where((h) => (cost[h] ?? -1) < 0);
    final ordered = [...ok, ...bad];
    return ordered.isEmpty ? hosts.toList() : ordered;
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
    final hosts = await _preferredHosts();
    final urls = [
      for (final h in hosts)
        'wss://$h/?baseinfo=${Uri.encodeComponent(baseinfo)}'
    ];

    WebSocket? ws;
    String connectedHost = '';
    for (final ep in urls) {
      if (_closed) return;
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
      _send(_hexToBytes(_LAUNCH_REQ));
      _dbgPush('Launch(原包) 已发');
    });
    Timer(const Duration(milliseconds: 600), () {
      if (_closed) return;
      _sendRegister();
    });
    Timer(const Duration(milliseconds: 900), () {
      if (_closed) return;
      _sendSubscribeHistory();
    });
    Timer(const Duration(milliseconds: 1200), () {
      if (_closed) return;
      _sendRctTimedMessage();
    });

    _heartTimer?.cancel();
    _heartTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendUserHeartBeat();
      _sendHeartbeat();
    });
  }

  /// ★ 网页真实 launch.wsTimeSync 请求原包
  static const _LAUNCH_REQ =
      '00031d00003b0000003b10032c3c400256066c61756e6368660a777354696d6553796e637d0000140800010604745265711d0000070a06001106b90b8c980ca80c2c3625353338336237376333313032386562353a353338336237376333313032386562353a303a304c5c66203234303062366437333638666631393331323664386365356237386230663433';

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

  void _sendUserHeartBeat() {
    try {
      final cookie = HuyaLoginManager().cookie;
      final uaInfo = _TarsWriter();
      uaInfo.writeString(1, _guid);
      uaInfo.writeString(3, _sendHuYaUA);
      uaInfo.writeString(4, cookie.isNotEmpty ? cookie : _cookie);
      uaInfo.writeString(5, 'edg');

      final req = _TarsWriter();
      req.writeStruct(0, uaInfo);
      req.writeInt(2, _ayyuid);
      req.writeString(3, '${_randHex(16)}:${_randHex(16)}:0:0');
      req.writeString(4, _randHex(31));
      req.writeInt(10, 14);
      req.writeInt(11, 1);

      final body =
          _wupBody('onlineui', 'OnUserHeartBeat', {'tReq': _treq(req.toBytes())});
      _send(_wrapWsCmd(_withPrefix(body), 3));
    } catch (_) {}
  }

  void _sendSubscribeHistory() {
    _sendSub33(_SUB33_CHAT);
    _sendSub33(_SUB33_LIVE);
  }

  void _sendSub33(String template) {
    try {
      if (_ayyuid <= 0) return;
      var bytes = _hexToBytes(template);

      if (_guid.length == 32) {
        final g = utf8.encode(_guid);
        for (var i = 0; i < 32; i++) {
          bytes[16 + i] = g[i];
        }
      }

      const oldId = '1279521053571';
      final newId = '$_ayyuid';
      if (newId != oldId) {
        for (final prefix in const ['live:', 'chat:']) {
          final oldStr = utf8.encode('$prefix$oldId');
          final idx = _indexOf(bytes, oldStr);
          if (idx > 0) {
            final newStr = utf8.encode('$prefix$newId');
            bytes = <int>[
              ...bytes.sublist(0, idx - 1),
              newStr.length,
              ...newStr,
              ...bytes.sublist(idx + oldStr.length),
            ];
          }
        }
      }

      final cmd = _TarsWriter();
      cmd.writeInt(0, 33);
      cmd.writeBytes(1, bytes);
      cmd.writeInt(2, ++_reqId);
      _send(cmd.toBytes());
      _dbgPush('订阅33(${template == _SUB33_CHAT ? "chat" : "live"}) 已发');
    } catch (_) {}
  }

  /// ★ 拉取下播历史弹幕：mobileui.getRctTimedMessage
  void _sendRctTimedMessage() {
    try {
      if (_ayyuid <= 0) return;
      final cookie = HuyaLoginManager().cookie;

      final uaInfo = _TarsWriter();
      uaInfo.writeInt(0, _ayyuid);
      uaInfo.writeString(1, _guid);
      uaInfo.writeString(2, '');
      uaInfo.writeString(3, _sendHuYaUA);
      uaInfo.writeString(4, cookie);
      uaInfo.writeString(5, 'edg');
      uaInfo.writeString(6, '');
      uaInfo.writeString(7, '');

      final req = _TarsWriter();
      req.writeStruct(0, uaInfo);
      req.writeInt(1, _ayyuid);
      req.writeInt(2, 0);
      req.writeInt(3, 0);
      req.writeInt(8, 0);
      req._head(9, 8);
      req._intValue(0);
      req._head(10, 8);
      req._intValue(0);
      req.writeInt(2, 0);
      req.writeString(3, '${_randHex(16)}:${_randHex(16)}:0:0');
      req.writeInt(4, 0);
      req.writeInt(5, 0);
      req.writeString(6, _randHex(32));

      final body = _wupBody('mobileui', 'getRctTimedMessage',
          {'tReq': _treq(req.toBytes())});
      _send(_wrapWsCmd(_withPrefix(body), 3));
      _dbgPush('请求历史弹幕 已发');
    } catch (_) {}
  }

  // ================= 发送弹幕 =================
  Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0) return false;
    if (!_verified || !_registered) {
      _dbgPush('未认证/未注册');
      return false;
    }
    try {
      _pendingDanmaku = text;
      final req = _buildSendReq(text);
      final body = _wupBody('liveui', 'sendMessage', {'tReq': _treq(req)});
      final framed = _withPrefix(body);

      _send(_wrapWsCmd(framed, 3, md5.convert(framed).toString()));
      _dbgPush('WS 已发');
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
    req.writeInt(2, _subSid > 0 ? _subSid : _topSid);
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

  Uint8List _wupBody(String servant, String func, Map<String, List<int>> buffers) {
    final inner = _TarsWriter();
    inner.writeBytesMap(0, buffers);

    final wup = _TarsWriter();
    wup.writeInt(1, 3);
    wup.writeInt(2, 0);
    wup.writeInt(3, 0);
    wup.writeInt(4, ++_reqId);
    wup.writeString(5, servant);
    wup.writeString(6, func);
    wup.writeBytes(7, inner.toBytes());
    wup.writeInt(8, 0);
    wup.writeBytesMap(9, const {});
    wup.writeBytesMap(10, const {});
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
        case 33:
          _dbgPush('分组状态(33)');
          break;
        case 34:
          final f = _TarsReader(payload).readFields();
          final v = f[0] is int ? f[0] as int : -1;
          _dbgPush('Register34 iResCode=$v');
          break;
        case 4:
          _handleWupRsp(payload);
          break;
        case 21:
          break;
        case 22:
        case 7:
          _handleMsgPushUnified(payload);
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

  void _handleWupRsp(List<int> bytes) {
    try {
      final f = _readWupFields(bytes);
      final servant = '${f[5] ?? ''}';
      final func = '${f[6] ?? ''}';

      // ★ 历史弹幕响应：tRsp = {0:{0:[N条]}}，剥两层
      if (servant == 'mobileui' && func == 'getRctTimedMessage') {
        int n = 0;
        final sb = f[7];
        if (sb is List) {
          try {
            final inner = _TarsReader(Uint8List.fromList(
                    sb.map((e) => (e as int) & 0xFF).toList()))
                .readFields();
            final map = inner[0];
            if (map is List) {
              for (var i = 0; i + 1 < map.length; i += 2) {
                if ('${map[i]}' == 'tRsp' && map[i + 1] is List) {
                  final rsp = _TarsReader(Uint8List.fromList((map[i + 1] as List)
                          .map((e) => (e as int) & 0xFF).toList()))
                      .readFields();
                  dynamic node = rsp[0];
                  if (node is Map<int, Object?>) {
                    node = node[0] ?? node[1];
                  }
                  if (node is List) {
                    for (final item in node) {
                      if (item is Map<int, Object?> && _emitFromFields(item)) {
                        n++;
                      }
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
        _dbgPush('历史弹幕 $n 条');
        return;
      }

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
              final rspBytes = Uint8List.fromList(
                  (map[i + 1] as List).map((e) => (e as int) & 0xFF).toList());
              final rsp = _TarsReader(rspBytes).readFields();
              ret = rsp[0] is int ? rsp[0] as int : -99;

              if (servant == 'launch' && ret == 0) {
                _parseLaunchRsp(rsp);
              }
            }
          }
        }
      }
      _dbgPush('WupRsp $servant.$func iRet=$ret');
    } catch (_) {
      _dbgPush('WupRsp 解析失败');
    }
  }

  void _parseLaunchRsp(Map<int, Object?> rsp) {
    final newHosts = <String>[];
    for (final entry in rsp.entries) {
      if (entry.value is List) {
        final list = entry.value as List;
        if (list.isNotEmpty && list.first is String) {
          for (final item in list) {
            if (item is String) {
              if (item.contains('huya.com')) {
                newHosts.add(item);
              } else if (item.contains(':')) {
                newHosts.add(item.split(':').first);
              }
            }
          }
        }
      }
    }

    if (newHosts.isNotEmpty) {
      _dynamicHosts = newHosts.toSet().toList();
      _dbgPush('动态节点更新: ${_dynamicHosts.length}个');
    }
  }

  void _handleMsgPushUnified(Uint8List payload) {
    try {
      final f = _TarsReader(payload).readFields();

      for (final key in const [1, 0, 2]) {
        final v = f[key];
        if (v is List && v.isNotEmpty) {
          bool isItemList = false;
          for (final item in v) {
            if (item is Map<int, Object?>) {
              isItemList = true;
              final uri = item[0] is int ? item[0] as int : 1400;
              final raw = item[1];
              if (raw is List) {
                _routePush(uri, raw.map((e) => (e as int) & 0xFF).toList());
              } else if (raw is Uint8List) {
                _routePush(uri, raw);
              }
            }
          }
          if (isItemList) return;
        }
      }

      final uri = f[1] is int ? f[1] as int : 1400;
      final raw = f[2];
      if (raw is List) {
        _routePush(uri, raw.map((e) => (e as int) & 0xFF).toList());
        return;
      } else if (raw is Uint8List) {
        _routePush(uri, raw);
        return;
      }

      if (f[3] is String || f[0] is Map<int, Object?>) {
        _decodeDanmaku(payload);
      }
    } catch (e) {
      _dbgPush('Push解析异常: $e');
    }
  }

  void _routePush(int uri, List<int> payload) {
    if (uri == 1400) {
      _decodeDanmaku(payload);
    } else if (uri == 6500 || uri == 6501 || uri == 6502) {
      if (!_decodeDanmaku(payload)) _decodeHistoryDanmaku(payload);
    } else if (uri == 8006) {
      try {
        final f = _TarsReader(Uint8List.fromList(payload)).readFields();
        final v = f[0] is int ? f[0] as int : 0;
        if (v > 0) onPopularity?.call(v);
      } catch (_) {}
    }
  }

  bool _decodeDanmaku(List<int> payload) {
    try {
      final fields = _TarsReader(Uint8List.fromList(payload)).readFields();
      return _emitFromFields(fields);
    } catch (_) {
      return false;
    }
  }

  /// ★ 弹幕发射器：实时/历史共用，自动兼容历史包多套的一层 struct
  bool _emitFromFields(Map<int, Object?> fields) {
    // ★ 历史包整体多嵌套一层：fields[0] = {0:sender, 3:content, ...}
    Map<int, Object?> msg = fields;
    if (fields[3] is! String && fields[0] is Map<int, Object?>) {
      final inner = fields[0] as Map<int, Object?>;
      if (inner[3] is String) msg = inner;
    }

    final content = msg[3];
    if (content is! String || content.isEmpty) return false;

    var sender = msg[0];
    if (sender is! Map<int, Object?>) return false;
    // 历史包 sender 还多一层：{0:{0:uid,2:昵称,4:头像}}
    if (sender[0] is Map<int, Object?>) {
      sender = sender[0] as Map<int, Object?>;
    }
    final uidVal = sender[0];
    if (uidVal is! int) return false;

    String nick = '';
    String avatar = '';
    for (final v in sender.values) {
      if (v is String) {
        if (v.startsWith('http') && avatar.isEmpty) {
          avatar = v;
        } else if (!v.startsWith('http') && v.isNotEmpty && nick.isEmpty) {
          nick = v;
        }
      }
    }
    if (nick.isEmpty) return false;

    int color = 0;
    for (final k in const [6, 5, 4]) {
      final cf = msg[k];
      if (cf is Map<int, Object?>) {
        if (cf[0] is int && (cf[0] as int) >= 0x10000 && (cf[0] as int) <= 0xFFFFFF) {
          color = cf[0] as int;
          break;
        }
        for (final v in cf.values) {
          if (v is int && v >= 0x10000 && v <= 0xFFFFFF) {
            color = v;
            break;
          }
        }
      }
      if (color != 0) break;
    }

    int managerType = 0;
    final mt = msg[7];
    if (mt is int && mt > 0 && mt <= 3) managerType = mt;

    String fansName = '';
    int fansLevel = 0;
    bool isName(dynamic s) =>
        s is String &&
        s.isNotEmpty &&
        !s.startsWith('http') &&
        s.length <= 12 &&
        s != nick &&
        s != content;
    void findFans(dynamic node, int depth) {
      if (fansName.isNotEmpty || depth > 6) return;
      if (node is Map<int, Object?>) {
        if (isName(node[3]) && node[4] is int && node[4] as int >= 1 && node[4] as int <= 99) {
          fansName = node[3] as String;
          fansLevel = node[4] as int;
          return;
        }
        if (isName(node[2]) && node[3] is int && node[3] as int >= 1 && node[3] as int <= 99 && node[0] is int) {
          fansName = node[2] as String;
          fansLevel = node[3] as int;
          return;
        }
        for (final e in node.entries) {
          if (depth == 0 && e.key == 0) continue;
          findFans(e.value, depth + 1);
        }
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            final inner =
                _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
            if (inner.isNotEmpty) findFans(inner, depth + 1);
          } catch (_) {}
        } else {
          for (final e in node) {
            findFans(e, depth + 1);
          }
        }
      }
    }

    findFans(msg, 0);

    _controller.add(DanmakuMessage(
      nickname: nick,
      content: content,
      fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000),
      avatar: avatar,
      uid: uidVal,
      fansName: fansName,
      fansLevel: fansLevel,
      managerType: managerType,
    ));

    if (_pendingDanmaku != null && content == _pendingDanmaku) {
      _pendingDanmaku = null;
      _dbgPush('回显确认 ✔');
    }
    return true;
  }

  /// ★ 历史条目兜底：tag5=昵称 tag6=内容
  void _decodeHistoryDanmaku(List<int> payload) {
    try {
      final fields = _TarsReader(Uint8List.fromList(payload)).readFields();
      final nick = fields[5] is String ? fields[5] as String : '';
      final content = fields[6] is String ? fields[6] as String : '';
      if (nick.isEmpty || content.isEmpty || content == nick) return;

      String avatar = '';
      for (final v in fields.values) {
        if (v is String && v.startsWith('http')) {
          avatar = v;
          break;
        }
      }

      _controller.add(DanmakuMessage(
        nickname: nick,
        content: content,
        avatar: avatar,
      ));
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
    if (t == 12) {
      _b.addByte(0x0C);
      return;
    }
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

  void writeListInt(int tag, List<int> items) {
    _head(tag, 9);
    _intValue(items.length);
    for (final v in items) {
      writeInt(0, v);
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
