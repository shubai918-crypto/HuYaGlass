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
  final int managerType;
  final List<String> badgeUrls;
  final bool isHistory;
  DanmakuMessage({
    required this.nickname,
    required this.content,
    this.fontColor = 0xFFFFFFFF,
    this.avatar = '',
    this.uid = 0,
    this.fansName = '',
    this.fansLevel = 0,
    this.managerType = 0,
    this.badgeUrls = const [],
    this.isHistory = false,
  });
  static const kBadgeManager =
      'https://livewebbs2.msstatic.com/newfangguan_3.png';
}

/// 高能用户（守护/贵宾/在线）
class VipUser {
  final String nickname;
  final String avatar;
  final int uid;
  final int guardLevel; // 守护等级 1/2/3
  final String guardIcon;
  final int nobleLevel; // 贵族/爷牌等级
  final String nobleIcon;
  final String fansName;
  final int fansLevel;
  final int managerType;
  final String pendantIcon;
  VipUser({
    this.nickname = '',
    this.avatar = '',
    this.uid = 0,
    this.guardLevel = 0,
    this.guardIcon = '',
    this.nobleLevel = 0,
    this.nobleIcon = '',
    this.fansName = '',
    this.fansLevel = 0,
    this.managerType = 0,
    this.pendantIcon = '',
  });
}

class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0';
  static const _sendHuYaUA = 'webh5&2608191804&websocket';
  static const _emoHuYaUA = 'webh5&0.1.0&websocket';

  static const _wsHosts = [
    'ded35397-ws.va.huya.com',
    '65cecb22-ws.va.huya.com',
    'wsapi.huya.com',
    'cdnws.api.huya.com',
  ];

  static const _SUB33_LIVE =
      '060c48555941265a482632303532162030613764666161323338353538323661326330316239383562613835363639632c3c6a08000106126c6976653a31323739353231303533353731180008011893100101194f100101195110010119531001011bc31001011bc41001011bc51001011bca1001180c30010b780c8c2c36004c5c6600';
  static const _SUB33_CHAT =
      '060c48555941265a482632303532162030613764666161323338353538323661326330316239383562613835363639632c3c6a0800010612636861743a313237393532313035333537311800010118431001180c30010b780c8c2c36004c5c6600';

  WebSocket? _ws;
  Timer? _heartTimer;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _recvCount = 0;
  int _topSid = 0;
  int _subSid = 0;
  int _ayyuid = 0;
  int _reqId = 0;
  int _cmdSeq = 0;
  String? _pendingDanmaku;
  String _roomIdStr = '';
  bool _verified = false;
  bool _registered = false;
  bool _rctOk = false;
  String _traceId = '';

  int _loginUid = 0;
  String _guid = '';
  String _cookie = '';
  List<String> _dynamicHosts = [];

  void Function(String)? onStatus;
  void Function(int)? onPopularity;
  void Function(String)? onSendDebug;
  void Function()? onEmoteReady;

  final List<String> _dbg = [];
  void _dbgPush(String s) {
    _dbg.add(s);
    if (_dbg.length > 30) _dbg.removeAt(0);
    onSendDebug?.call(_dbg.join('\n'));
  }

  final StreamController<DanmakuMessage> _controller =
      StreamController<DanmakuMessage>.broadcast();
  Stream<DanmakuMessage> get danmakuStream => _controller.stream;

  /// 高能用户（守护/贵宾）
  final List<VipUser> guardList = [];
  final List<VipUser> vipList = [];
  final StreamController<List<VipUser>> _vipController =
      StreamController<List<VipUser>>.broadcast();
  Stream<List<VipUser>> get vipStream => _vipController.stream;

  /// 表情注册表（运行时解析 + 归一化）
  static final Map<String, String> emoteRegistry = {};

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
        if (bytes[i + j] != pattern[j]) { ok = false; break; }
      }
      if (ok) return i;
    }
    return -1;
  }

  /// ★ 表情 URL 归一化：steam.png -> steam_3.png
  static String _fixEmoteUrl(String url) {
    const bad = 'steam.png';
    if (url.endsWith(bad)) {
      return url.substring(0, url.length - bad.length) + 'steam_3.png';
    }
    return url;
  }

  Future<List<String>> _preferredHosts() async {
    final hosts = _dynamicHosts.isNotEmpty ? _dynamicHosts : _wsHosts;
    final cost = <String, int>{};
    await Future.wait(hosts.map((h) async {
      final sw = Stopwatch()..start();
      try {
        final addrs = await InternetAddress.lookup(h)
            .timeout(const Duration(seconds: 2));
        sw.stop();
        cost[h] = addrs.isNotEmpty ? sw.elapsedMilliseconds : -1;
      } catch (_) { cost[h] = -1; }
    }));
    final ok = hosts.where((h) => (cost[h] ?? -1) >= 0).toList()
      ..sort((a, b) => cost[a]! - cost[b]!);
    final bad = hosts.where((h) => (cost[h] ?? -1) < 0);
    final ordered = [...ok, ...bad];
    return ordered.isEmpty ? hosts.toList() : ordered;
  }

  Future<void> connect({
    required int topSid,
    required int subSid,
    int uid = 0,
    String roomIdStr = '',
  }) async {
    _closed = false;
    _recvCount = 0;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid > 0 ? uid : topSid;
    _roomIdStr = roomIdStr;
    _verified = false;
    _registered = false;
    _rctOk = false;
    _cmdSeq = 0;
    guardList.clear();
    vipList.clear();

    _cookie = HuyaLoginManager().cookie;
    _loginUid = int.tryParse(_cookieVal('yyuid')) ??
        (int.tryParse(_cookieVal('udb_uid')) ?? 0);
    _guid = _cookieVal('guid');
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
        ws = await WebSocket.connect(ep, headers: {
          'Origin': 'https://www.huya.com',
          'User-Agent': _ua,
          'Cache-Control': 'no-cache',
        }, compression: CompressionOptions.compressionDefault)
            .timeout(const Duration(seconds: 6));
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
      if (!_closed) _fetchEmoticonPackage();
    });
    Timer(const Duration(milliseconds: 1500), () {
      if (!_closed) _sendRctTimedMessage();
    });
    Timer(const Duration(milliseconds: 1800), () {
      if (!_closed) _sendVipbarRegister();
    });
    Timer(const Duration(milliseconds: 4500), () {
      if (!_closed && !_rctOk) _sendRctTimedMessage();
    });

    _heartTimer?.cancel();
    _heartTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendUserHeartBeat();
      _sendHeartbeat();
    });
  }

  static const _LAUNCH_REQ =
      '00031d00003b0000003b10032c3c400256066c61756e6368660a777354696d6553796e637d0000140800010604745265711d0000070a06001106b90b8c980ca80c2c3625353338336237376333313032386562353a353338336237376333313032386562353a303a304c5c66203234303062366437333638666631393331323664386365356237386230663433';

  void _sendRegister() {
    _send(_buildRegisterGroup());
    _registered = true;
    _dbgPush('Register(16) 已发');
  }

  String _buildBaseinfo() {
    final info = _TarsWriter();
    info.writeInt(0, _loginUid);
    info.writeString(1, _guid);
    info.writeString(2, _emoHuYaUA);
    info.writeString(3, 'HUYA&ZH&2052');
    info.writeString(4, '');
    info.writeString(5, '');
    info.writeInt(6, 0);
    info.writeString(7, '');
    info.writeInt(8, 0);
    info.writeString(9, '');
    info.writeInt(10, 0);
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

  /// ★ 注册 vipbar 组（守护/贵宾）
  void _sendVipbarRegister() {
    try {
      final req = _TarsWriter();
      req.writeStringList(0, ['comm:vipbar_$_ayyuid']);
      req.writeString(1, '');
      final cmd = _TarsWriter();
      cmd.writeInt(0, 16);
      cmd.writeBytes(1, req.toBytes());
      cmd.writeInt(2, ++_reqId);
      _send(cmd.toBytes());
      _dbgPush('Register(vipbar) 已发');
    } catch (_) {}
  }

  void _sendHeartbeat() {
    final cmd = _TarsWriter();
    cmd.writeInt(0, 20);
    cmd.writeBytes(1, const []);
    _send(cmd.toBytes());
  }

  void _sendUserHeartBeat() {
    try {
      final uaInfo = _TarsWriter();
      uaInfo.writeString(1, _guid);
      uaInfo.writeString(3, _sendHuYaUA);
      uaInfo.writeString(4, _cookie);
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
        for (var i = 0; i < 32; i++) bytes[16 + i] = g[i];
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
      _dbgPush('订阅33 已发');
    } catch (_) {}
  }

  /// ★ 表情包：独立请求 + 解析 + 归一化
  void _fetchEmoticonPackage() {
    try {
      final myUid = _loginUid > 0 ? _loginUid : _ayyuid;
      final uaInfo = _TarsWriter();
      uaInfo.writeInt(0, myUid);
      uaInfo.writeString(1, _guid);
      uaInfo.writeString(2, '');
      uaInfo.writeString(3, _emoHuYaUA);
      uaInfo.writeString(4, _cookie);
      uaInfo.writeInt(5, 0);
      uaInfo.writeString(6, '');
      uaInfo.writeString(7, '');
      final req = _TarsWriter();
      req.writeStruct(0, uaInfo);
      req.writeInt(1, _ayyuid);
      req.writeInt(2, 0);
      req.writeInt(3, 0);
      final body = _wupBody('wupui', 'getExpressionEmoticonPackage',
          {'tReq': _treq(req.toBytes())});
      _send(_wrapWsCmd(_withPrefix(body), 3));
      _dbgPush('请求表情包 已发');
    } catch (_) {}
  }

  void _sendRctTimedMessage() {
    try {
      if (_ayyuid <= 0) return;
      final myUid = _loginUid > 0 ? _loginUid : _ayyuid;
      final uaInfo = _TarsWriter();
      uaInfo.writeInt(0, myUid);
      uaInfo.writeString(1, _guid);
      uaInfo.writeString(2, '');
      uaInfo.writeString(3, _sendHuYaUA);
      uaInfo.writeString(4, _cookie);
      uaInfo.writeInt(5, 0);
      uaInfo.writeString(6, 'edg');
      uaInfo.writeString(7, '');
      final info = _TarsWriter();
      info.writeStruct(0, uaInfo);
      info.writeInt(1, _ayyuid);
      info.writeInt(2, 0);
      info.writeInt(3, 0);
      final req = _TarsWriter();
      req.writeStruct(0, info);
      req.writeInt(2, 0);
      req.writeString(3, '${_randHex(16)}:${_randHex(16)}:0:0');
      req.writeInt(4, 0);
      req.writeInt(5, 0);
      req.writeString(6, _randHex(32));
      req.writeInt(8, 0);
      req.writeBytesMap(9, const {});
      req.writeBytesMap(10, const {});
      final body =
          _wupBody('mobileui', 'getRctTimedMessage', {'tReq': req.toBytes()});
      _send(_wrapWsCmd(_withPrefix(body), 3));
      _dbgPush('请求历史弹幕 已发');
    } catch (_) {}
  }

  Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0) return false;
    if (!_verified || !_registered) return false;
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
    cf.writeInt(0, -1); cf.writeInt(1, 4); cf.writeInt(2, 0);
    cf.writeInt(3, -1); cf.writeInt(4, -1); cf.writeInt(5, -1);
    final border = _TarsWriter();
    border.writeInt(0, 0); border.writeInt(1, 0); border.writeInt(2, -1);
    border.writeInt(3, 100); border.writeInt(4, -1); border.writeInt(5, 100);
    border.writeString(6, ''); border.writeInt(7, -1); border.writeInt(8, -1);
    final bf = _TarsWriter();
    bf.writeInt(0, -1); bf.writeInt(1, 4); bf.writeInt(2, 0); bf.writeInt(3, 1);
    bf.writeInt(4, 0); bf.writeStruct(5, border); bf.writeListInt(6, const []);
    bf.writeInt(7, 0); bf.writeInt(8, -1);
    final sence = _TarsWriter();
    sence.writeInt(0, 0); sence.writeInt(1, 0); sence.writeInt(2, 0);
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
    wup.writeInt(1, 3); wup.writeInt(2, 0); wup.writeInt(3, 0);
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
    try { _ws?.close(); } catch (_) {}
    _ws = null;
  }

  void _onData(dynamic data) {
    try {
      _recvCount++;
      final bytes = Uint8List.fromList((data as List).cast<int>());
      final fields = _TarsReader(bytes).readFields();
      final cmdType = fields[0] is int ? fields[0] as int : -1;
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
          if (v == 0) _verified = true;
          break;
        case 17:
          final f = _TarsReader(payload).readFields();
          final v = f[0] is int ? f[0] as int : -1;
          if (v == 0) _registered = true;
          break;
        case 4:
          _handleWupRsp(payload);
          break;
        case 21:
          break;
        case 22:
          // ★ 守护推送（comm:vipbar）
          if (_isVipbarPush(payload)) {
            _parseGuardPush(payload);
          } else {
            _handleMsgPushUnified(payload);
          }
          break;
        case 7:
          if (_isVipbarPush(payload)) {
            _parseVipPush(payload);
          } else {
            _handleMsgPushUnified(payload);
          }
          break;
        default:
          _handleMsgPushUnified(payload);
          break;
      }
      onStatus?.call('收包$_recvCount cmd=$cmdType');
    } catch (_) {}
  }

  bool _isVipbarPush(Uint8List payload) {
    try {
      final s = utf8.decode(payload.sublist(0, min(40, payload.length)),
          allowMalformed: true);
      return s.contains('vipbar');
    } catch (_) { return false; }
  }

  /// ★ 解析守护列表
  void _parseGuardPush(Uint8List payload) {
    try {
      guardList.clear();
      void walk(dynamic node, int depth) {
        if (depth > 10) return;
        if (node is Map<int, Object?>) {
          final nick = _firstString(node, [6, 2, 1]);
          final avatar = _firstUrl(node);
          if (nick.isNotEmpty && avatar.isNotEmpty) {
            final guardIcon = _firstUrlContains(node, 'guardrank');
            int gl = 0;
            if (guardIcon.contains('/1.png')) gl = 1;
            else if (guardIcon.contains('/2.png')) gl = 2;
            else if (guardIcon.contains('/3.png')) gl = 3;
            guardList.add(VipUser(
              nickname: nick, avatar: avatar,
              guardLevel: gl, guardIcon: guardIcon,
              nobleIcon: _firstUrlContains(node, 'yepai'),
              pendantIcon: _firstUrlContains(node, 'Pendant'),
              fansName: _fansOf(node).$1, fansLevel: _fansOf(node).$2,
              managerType: _managerOf(node),
            ));
            return;
          }
          node.values.forEach((v) => walk(v, depth + 1));
        } else if (node is List) {
          node.forEach((v) => walk(v, depth + 1));
        }
      }
      walk(_TarsReader(payload).readFields(), 0);
      _vipController.add(List.from(guardList));
      _dbgPush('守护 ${guardList.length} 人');
    } catch (_) {}
  }

  /// ★ 解析贵宾列表
  void _parseVipPush(Uint8List payload) {
    try {
      vipList.clear();
      void walk(dynamic node, int depth) {
        if (depth > 10) return;
        if (node is Map<int, Object?>) {
          final nick = _firstString(node, [6, 2, 1]);
          final avatar = _firstUrl(node);
          if (nick.isNotEmpty && avatar.isNotEmpty) {
            vipList.add(VipUser(
              nickname: nick, avatar: avatar,
              nobleIcon: _firstUrlContains(node, 'yepai'),
              guardIcon: _firstUrlContains(node, 'guardrank'),
              pendantIcon: _firstUrlContains(node, 'Pendant'),
              fansName: _fansOf(node).$1, fansLevel: _fansOf(node).$2,
              managerType: _managerOf(node),
            ));
            return;
          }
          node.values.forEach((v) => walk(v, depth + 1));
        } else if (node is List) {
          node.forEach((v) => walk(v, depth + 1));
        }
      }
      walk(_TarsReader(payload).readFields(), 0);
      _vipController.add(List.from(vipList));
      _dbgPush('贵宾 ${vipList.length} 人');
    } catch (_) {}
  }

  String _firstString(Map<int, Object?> m, List<int> tags) {
    for (final t in tags) {
      final v = m[t];
      if (v is String && v.isNotEmpty && !v.startsWith('http')) return v;
    }
    for (final v in m.values) {
      if (v is String && v.isNotEmpty && !v.startsWith('http')) return v;
    }
    return '';
  }

  String _firstUrl(Map<int, Object?> m) {
    for (final v in m.values) {
      if (v is String && v.startsWith('http') && v.contains('avatar')) return v;
    }
    for (final v in m.values) {
      if (v is String && v.startsWith('http')) return v;
    }
    return '';
  }

  String _firstUrlContains(Map<int, Object?> m, String key) {
    String found = '';
    void walk(dynamic node, int depth) {
      if (found.isNotEmpty || depth > 6) return;
      if (node is String) {
        if (node.startsWith('http') && node.contains(key)) { found = node; return; }
      } else if (node is Map<int, Object?>) {
        node.values.forEach((v) => walk(v, depth + 1));
      } else if (node is List) {
        node.forEach((v) => walk(v, depth + 1));
      }
    }
    walk(m, 0);
    return found;
  }

  (String, int) _fansOf(Map<int, Object?> m) {
    String name = ''; int level = 0;
    void walk(dynamic node, int depth) {
      if (name.isNotEmpty || depth > 6) return;
      if (node is Map<int, Object?>) {
        if (node[3] is String && node[4] is int) {
          name = node[3] as String; level = node[4] as int; return;
        }
        node.values.forEach((v) => walk(v, depth + 1));
      } else if (node is List) {
        node.forEach((v) => walk(v, depth + 1));
      }
    }
    walk(m, 0);
    return (name, level);
  }

  int _managerOf(Map<int, Object?> m) {
    final v = m[7];
    if (v is int && v > 0 && v <= 3) return v;
    return 0;
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

      // ★ 表情包响应：解析并归一化
      if (servant == 'wupui' && func == 'getExpressionEmoticonPackage') {
        int cnt = 0;
        void walk(dynamic node, int depth) {
          if (depth > 12) return;
          if (node is Map<int, Object?>) {
            final name = node[1];
            String? url;
            final u1 = node[3]; final u2 = node[4];
            if (u1 is String && u1.startsWith('http')) url = u1;
            else if (u2 is String && u2.startsWith('http')) url = u2;
            if (name is String && name.startsWith('[') && url != null) {
              emoteRegistry[name] = _fixEmoteUrl(url);
              cnt++;
            }
            node.values.forEach((v) => walk(v, depth + 1));
          } else if (node is List) {
            node.forEach((v) => walk(v, depth + 1));
          }
        }
        walk(f, 0);
        _dbgPush('表情 $cnt 个');
        if (cnt > 0) onEmoteReady?.call();
        return;
      }

      if (servant == 'mobileui' && func == 'getRctTimedMessage') {
        int n = 0;
        void collect(dynamic node, int depth) {
          if (depth > 14 || n > 60) return;
          if (node is Map<int, Object?>) {
            Map<int, Object?>? msgNode;
            if (node[3] is String && node[0] is Map<int, Object?>) msgNode = node;
            else if (node[0] is Map<int, Object?> &&
                (node[0] as Map<int, Object?>)[3] is String) {
              msgNode = node[0] as Map<int, Object?>;
            }
            if (msgNode != null && _emitFromFields(msgNode, history: true)) { n++; return; }
            node.values.forEach((v) => collect(v, depth + 1));
          } else if (node is List) {
            node.forEach((v) => collect(v, depth + 1));
          }
        }
        collect(f, 0);
        if (n > 0) _rctOk = true;
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
              if (servant == 'launch' && ret == 0) _parseLaunchRsp(rsp);
            }
          }
        }
      }
      _dbgPush('WupRsp $servant.$func iRet=$ret');
    } catch (_) {}
  }

  void _parseLaunchRsp(Map<int, Object?> rsp) {
    final newHosts = <String>[];
    for (final entry in rsp.entries) {
      if (entry.value is List) {
        final list = entry.value as List;
        if (list.isNotEmpty && list.first is String) {
          for (final item in list) {
            if (item is String) {
              if (item.contains('huya.com')) newHosts.add(item);
              else if (item.contains(':')) newHosts.add(item.split(':').first);
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
              if (raw is List) _routePush(uri, raw.map((e) => (e as int) & 0xFF).toList());
              else if (raw is Uint8List) _routePush(uri, raw);
            }
          }
          if (isItemList) return;
        }
      }
      final uri = f[1] is int ? f[1] as int : 1400;
      final raw = f[2];
      if (raw is List) { _routePush(uri, raw.map((e) => (e as int) & 0xFF).toList()); return; }
      else if (raw is Uint8List) { _routePush(uri, raw); return; }
      if (f[3] is String || f[0] is Map<int, Object?>) _decodeDanmaku(payload);
    } catch (_) {}
  }

  void _routePush(int uri, List<int> payload) {
    if (uri == 1400) _decodeDanmaku(payload);
    else if (uri == 6500 || uri == 6501 || uri == 6502) {
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
      return _emitFromFields(_TarsReader(Uint8List.fromList(payload)).readFields());
    } catch (_) { return false; }
  }

  bool _emitFromFields(Map<int, Object?> fields, {bool history = false}) {
    Map<int, Object?> msg = fields;
    if (fields[3] is! String && fields[0] is Map<int, Object?>) {
      final inner = fields[0] as Map<int, Object?>;
      if (inner[3] is String) msg = inner;
    }
    final content = msg[3];
    if (content is! String || content.isEmpty) return false;
    final senderRaw = msg[0];
    if (senderRaw is! Map<int, Object?>) return false;
    var sender = senderRaw;
    if (sender[0] is Map<int, Object?>) sender = sender[0] as Map<int, Object?>;
    final uidVal = sender[0];
    if (uidVal is! int) return false;

    String nick = ''; String avatar = '';
    for (final v in sender.values) {
      if (v is String) {
        if (v.startsWith('http') && avatar.isEmpty) avatar = v;
        else if (v.isNotEmpty && nick.isEmpty) nick = v;
      }
    }
    if (nick.isEmpty) return false;

    int color = 0;
    for (final k in const [6, 5, 4]) {
      final cf = msg[k];
      if (cf is Map<int, Object?>) {
        if (cf[0] is int && (cf[0] as int) >= 0x10000 && (cf[0] as int) <= 0xFFFFFF) { color = cf[0] as int; break; }
        for (final v in cf.values) {
          if (v is int && v >= 0x10000 && v <= 0xFFFFFF) { color = v; break; }
        }
      }
      if (color != 0) break;
    }

    int managerType = 0;
    final mt = msg[7];
    if (mt is int && mt > 0 && mt <= 3) managerType = mt;

    String fansName = ''; int fansLevel = 0;
    bool isName(dynamic s) => s is String && s.isNotEmpty && !s.startsWith('http') &&
        s.length <= 12 && s != nick && s != content;
    void findFans(dynamic node, int depth) {
      if (fansName.isNotEmpty || depth > 8) return;
      if (node is Map<int, Object?>) {
        if (isName(node[3]) && node[4] is int && (node[4] as int) >= 1 && (node[4] as int) <= 99) {
          fansName = node[3] as String; fansLevel = node[4] as int; return;
        }
        if (isName(node[2]) && node[3] is int && (node[3] as int) >= 1 && (node[3] as int) <= 99 && node[0] is int) {
          fansName = node[2] as String; fansLevel = node[3] as int; return;
        }
        node.values.forEach((v) => findFans(v, depth + 1));
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            final inner = _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
            if (inner.isNotEmpty) findFans(inner, depth + 1);
          } catch (_) {}
        } else node.forEach((v) => findFans(v, depth + 1));
      }
    }
    findFans(msg, 0);

    final badges = <String>[];
    void findBadges(dynamic node, int depth) {
      if (depth > 8) return;
      if (node is Map<int, Object?>) node.values.forEach((v) => findBadges(v, depth + 1));
      else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            findBadges(_TarsReader(Uint8List.fromList(node.cast<int>())).readFields(), depth + 1);
          } catch (_) {}
        } else node.forEach((v) => findBadges(v, depth + 1));
      } else if (node is String && node.startsWith('http')) {
        if (node.contains('guiyepai') || node.contains('PendantInfoZip') ||
            node.contains('fenzuan') || node.contains('fengzuan') || node.contains('fangguan')) {
          if (!badges.contains(node)) badges.add(node);
        }
      }
    }
    findBadges(msg, 0);
    badges.sort((a, b) {
      int rank(String u) => u.contains('guiyepai') ? 0 :
          (u.contains('PendantInfoZip') || u.contains('fenzuan') || u.contains('fengzuan')) ? 1 : 2;
      return rank(a).compareTo(rank(b));
    });

    _controller.add(DanmakuMessage(
      nickname: nick, content: content,
      fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000),
      avatar: avatar, uid: uidVal,
      fansName: fansName, fansLevel: fansLevel,
      managerType: managerType, badgeUrls: badges,
      isHistory: history,
    ));
    if (_pendingDanmaku != null && content == _pendingDanmaku) {
      _pendingDanmaku = null;
      _dbgPush('回显确认 ✔');
    }
    return true;
  }

  void _decodeHistoryDanmaku(List<int> payload) {
    try {
      final fields = _TarsReader(Uint8List.fromList(payload)).readFields();
      final nick = fields[5] is String ? fields[5] as String : '';
      final content = fields[6] is String ? fields[6] as String : '';
      if (nick.isEmpty || content.isEmpty || content == nick) return;
      String avatar = '';
      for (final v in fields.values) {
        if (v is String && v.startsWith('http')) { avatar = v; break; }
      }
      _controller.add(DanmakuMessage(nickname: nick, content: content, avatar: avatar, isHistory: true));
    } catch (_) {}
  }
}

// ================= Tars 编解码（同前，省略注释） =================
class _TarsWriter {
  final BytesBuilder _b = BytesBuilder();
  void _head(int tag, int type) {
    if (tag < 15) _b.addByte((tag << 4) | type);
    else { _b.addByte(0xF0 | type); _b.addByte(tag); }
  }
  int _intType(int v) {
    if (v == 0) return 12;
    if (v >= -128 && v <= 127) return 0;
    if (v >= -32768 && v <= 32767) return 1;
    if (v >= -2147483648 && v <= 2147483647) return 2;
    return 3;
  }
  void _add(int v, int n) { for (var i = n - 1; i >= 0; i--) _b.addByte((v >> (8 * i)) & 0xFF); }
  void _intValue(int v) {
    final t = _intType(v);
    if (t == 12) { _b.addByte(0x0C); return; }
    _b.addByte(t); _add(v, [1, 2, 4, 8][t]);
  }
  void writeInt(int tag, int v) { final t = _intType(v); _head(tag, t); if (t == 12) return; _add(v, [1, 2, 4, 8][t]); }
  void writeString(int tag, String s) {
    final b = utf8.encode(s);
    if (b.length < 256) { _head(tag, 6); _b.addByte(b.length); }
    else { _head(tag, 7); _add(b.length, 4); }
    _b.add(b);
  }
  void writeStringList(int tag, List<String> items) { _head(tag, 9); _intValue(items.length); for (final s in items) writeString(0, s); }
  void writeListInt(int tag, List<int> items) { _head(tag, 9); _intValue(items.length); for (final v in items) writeInt(0, v); }
  void writeBytes(int tag, List<int> bytes) { _head(tag, 13); _head(0, 0); _intValue(bytes.length); _b.add(bytes); }
  void writeMap(int tag, Map<String, String> entries) { _head(tag, 8); _intValue(entries.length); entries.forEach((k, v) { writeString(0, k); writeString(1, v); }); }
  void writeBytesMap(int tag, Map<String, List<int>> entries) { _head(tag, 8); _intValue(entries.length); entries.forEach((k, v) { writeString(0, k); writeBytes(1, v); }); }
  void writeStruct(int tag, _TarsWriter inner) { _head(tag, 10); _b.add(inner._b.toBytes()); _b.addByte(0x0B); }
  Uint8List toBytes() => Uint8List.fromList(_b.toBytes());
}

class _TarsReader {
  final Uint8List _d; int _pos = 0;
  _TarsReader(this._d);
  bool get hasMore => _pos < _d.length;
  int _byte() => _d[_pos++];
  int _readIntN(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) v = (v << 8) | _d[_pos++];
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
      case 4: final v = ByteData.sublistView(_d, _pos, _pos + 4).getFloat32(0); _pos += 4; return v;
      case 5: final v = ByteData.sublistView(_d, _pos, _pos + 8).getFloat64(0); _pos += 8; return v;
      case 6: final n = _byte(); final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true); _pos += n; return s;
      case 7: final n = _readIntN(4); final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true); _pos += n; return s;
      case 13: _byte(); final n = _readValueInt(); final bytes = _d.sublist(_pos, _pos + n); _pos += n; return bytes;
      case 9: final size = _readValueInt(); final list = <Object?>[]; for (var i = 0; i < size; i++) { final h = _byte(); var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); list.add(_readValue(h & 0x0F)); } return list;
      case 8: final size = _readValueInt(); final list = <Object?>[]; for (var i = 0; i < size * 2; i++) { final h = _byte(); var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); list.add(_readValue(h & 0x0F)); } return list;
      case 10: return readFields();
      default: throw FormatException('tars: unknown type $type');
    }
  }
}
