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
  DanmakuMessage({
    required this.nickname,
    required this.content,
    this.fontColor = 0xFFFFFFFF,
  });
}

/// 虎牙弹幕客户端（2026-08-22 抓包最终对齐版）
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0';
  static const _sendHuYaUA = 'webh5&2608191804&websocket';

  static const _endpoints = [
    'wss://ded35397-ws.va.huya.com', // 2026-08-22 最新抓包节点
    'wss://65cecb22-ws.va.huya.com',
    'wss://ws.va.huya.com',
    'wss://wsapi.huya.com',
    'wss://cdnws.api.huya.com',
  ];

  /// 浏览器抓包第 1 帧（huyaliveui.getLivingInfo）原样重放
  static const _frameGetLivingInfo =
      '00031d00010a1000000a1010032c3c4001560a687579616c6976657569660d6765744c6976696e67496e666f7d000109e10800010604745265711d000109d30a0a03000001174c374084162030613839333136653766303638393661336630316438363464393634636361352600361a7765626835263236303831393138303426776562736f636b6574470000093b5f5f79616d69645f6e65773d43424338464634343436393030303031443738303143413041354330383730303b2067616d655f6469643d4e6a3952354c7158414c72506e31303645504b623458564f52487457684152394b34543b20536f756e6456616c75653d302e35303b20677569643d30613839333136653766303638393661336630316438363464393634636361353b207564625f67756964646174613d34633331363038323434333834643235393834653630653433623136336335383b207564625f64657669636569643d775f313134333438383837313834363531343638383b205f71696d65695f7575696434323d3161383136306131303231313030666231343930346534393266613638623230393464653766646664623b20677569643d30613839333136653766303638393661336630316438363464393634636361353b207564625f616e6f7569643d313437313231343631303138303b207564625f616e6f62697a746f6b656e3d4151423865506e4f723348435a624878776f5249745f5a47736d553668517a475650304f7a723669692d4c36324b697a324941455945304a4c3135416b54544573775a7758645343672d706d3378556e326d3033522d497057425054736a5032305656794c5064774a5a6a736e32596a6e6942396d4168335a74716b415762772d687844594e365956366c70463168583076687275505444496575435148435f654254577339577639724434696c6b356631536c69456e5f66434d484d4471544473696e42537662625965316148625a52554b5963427261664f4a78383937516479784e4c6d39783369566c3278335a672d71744147495a35793336517872437164363150346c5346497030355f36634c37756441704872776c754c4f36485962387439647844304177514c42324777444757415f70444764524e4e574766383476306b4956554543566270612d3553354c6b76565458633b205f5f7961736d69643d302e353336363235323533393935373030353b205f5f79616d69645f7474313d302e353336363235323533393935373030353b20486d5f6c76745f35313730306236633732326635626234636633393930366135393665613431663d313738373336343939353b20484d4143434f554e543d353743324344374237374345394630463b20686469643d646363356333343233623062346539626233376533353561613663363538656631343462626361653b207564625f70617373646174613d333b20616c70686156616c75653d302e38303b206973496e4c697665526f6f6d3d747275653b207564625f61707069643d353030323b205f71696d65695f66696e6765727072696e743d63373765666266393636636339626139396664653261313339666661363761643b205f71696d65695f6833383d61666163663262383134393034653439326661363862323030323030303030376531613831363b206e756c6c5f7265705f636e743d323b20687579617761705f7265705f636e743d353b207564625f7569643d313139393537343536343939363b2079797569643d313139393537343536343939363b207564625f70617373706f72743d68795f3134313230303333323b20757365726e616d653d68795f3134313230303333323b207564625f76657273696f6e3d312e303b207564625f62697a746f6b656e3d4151435157304b697538646b616371686a735f3364397032384779524447797136612d777a766f466f447253636652654b68437978454f5a322d484363786f4e574a586e56627a676e7651746e51494543546176766c5a476d5f3033446e7176334d61747a64544b73586757684b496d434c4578664d726b77417a5773675678394a475976674a624e596935535a6347747566344258426a4867616845705551594572485a34345f6e32324a46436768354a6b5a5261553056364f4e73564b573632326f75434e6b42586d4d4a6234787a464b757444474e2d74782d48704f5a46374e347a6a5f446e5f6d484a41457a6e56715644746c5f70363278727a374a524d6e69716a6d2d6d5a714f76654d4141544d5f4462584c4b424d35644a78544a6d764d5539626d38425050753275794b65753632306d6233494d796873525630753445676574464449627676534b766e755846443767563b207564625f6f726967696e3d353b207564625f7374617475733d313b207564625f637265643d436f41583371774768693468386c6e416d6b5a364a6a752d475968493269524350304b734a7046756d623245557470485a442d5048645f356a5a6370434c4b4a766131674158416a38764438586f7169586344506f6b6d3047506471622d6a7638334d6e714c6f4a53485455673566434d747a6666434c6c62657964656a3253575749743458315869776e6246756a5f6c724d775541367a3b207564625f6f746865723d2537422532326c7425323225334125323231373837333635303539383430253232253243253232697352656d253232253341253232312532322537443b207564625f616363646174613d30383631353330343734353930393b20685f756e743d313738373336353036303b205f5f79616f6c6479797569643d313139393537343536343939363b205f7961736964733d5f5f726f6f7473696425334443424338464635353741343030303031393533454631393031333932313945463b206875796173705f7265705f636e743d31303b207265705f636e743d32323b20736469643d30556e48556776305f716d6644344b414b6c777a68715156534777684e7655734d7162656d6469565566386462365264535a6567386e375458724f466c7030467a6750492d797a58594949426d72375638476f38752d7a385f63304a4c48695154655a4e4a4c52505a36626a57566b6e394c7466464a775f516f346b674b72384f5a4844714e6e757767363132734779666c466e316468305068744f30675754305f5a7a52516b343272634679436f58735967776b7a5a4c71586466676f597a6e3b205f7265705f636e743d383b20486d5f6c7076745f35313730306236633732326635626234636633393930366135393665613431663d313738373336353537353b20687579615f666c6173685f7265705f636e743d3135363b20687579615f68645f7265705f636e743d34333b20687579615f7765625f7265705f636e743d3736313b20687579615f75613d7765626835263236303831393138303426776562736f636b65745c660365646776000b1c2c330000011751b5a204462be79bb4e692ade58897e8a1a8e9a1b52fe78e8be88085e88da3e880802fe79bb4e692ade58da1e789872f3256006c7c80010b8c980ca80c2c3625383763373631643939633762383566383a383763373631643939633762383566383a303a304c5c66206466333061373239316435313236363532666363616536616433356563306130';

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

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
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

    // ★ 顺序：getLivingInfo(原样重放) → VerifyCookie → wsTimeSync → RegisterGroup
    _send(_hexToBytes(_frameGetLivingInfo));
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
      _send(_buildRegisterGroup());
    });

    _heartTimer?.cancel();
    _heartTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
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
    info.writeString(4, ''); // tag4 空串
    info.writeString(5, mid); // tag5 = mid
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

  /// tReq 值 = 外层 struct 包装（0x0A + 字段流 + 0x0B）
  Uint8List _treq(Uint8List structFields) {
    final out = BytesBuilder();
    out.addByte(0x0A);
    out.add(structFields);
    out.addByte(0x0B);
    return out.toBytes();
  }

  Uint8List _buildGetLivingInfoReq() {
    final user = _TarsWriter();
    user.writeInt(0, _loginUid);
    user.writeString(1, _guid);
    user.writeString(2, '');
    user.writeString(3, _sendHuYaUA);
    user.writeString(4, _cookie);
    user.writeInt(5, 0);
    user.writeString(6, 'edg');
    user.writeString(7, '');
    final req = _TarsWriter();
    req.writeStruct(0, user);
    req.writeInt(1, 0);
    req.writeInt(3, _topSid);
    req.writeString(4, '');
    req.writeString(5, '');
    req.writeInt(6, 0);
    req.writeInt(7, 0);
    req.writeInt(8, 1);
    return req.toBytes();
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

      _send(_wrapWsCmd(framed, 3));
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

  /// WebSocketCommand（补上 tag2 lRequestId=0）
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
          if (v == 0) {
            _registered = true;
            _dbgPush('就绪 ✔');
          }
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
