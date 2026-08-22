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

/// 虎牙弹幕客户端（逐字节对齐 2026-08-21 真实抓包 + 压缩协商 + 差分诊断）
class HuyaDanmakuClient {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0';
  static const _sendHuYaUA = 'webh5&2608191804&websocket';

  /// 信令节点（抓包确认：只有 va 节点处理 WUP 发送）
  static const _endpoints = [
    'wss://65cecb22-ws.va.huya.com',
    'wss://ws.va.huya.com',
    'wss://wsapi.huya.com',
    'wss://cdnws.api.huya.com',
  ];

  /// 浏览器抓包原始帧（差分测试：发送内容输入 replay 时原样重放）
  static const _replayHex =
      '00031d00010a2b00000a2b10032c3c404856066c6976657569660b73656e644d6573736167657d00010a020800010604745265711d000109f40a0a03000001174c374084162030613764666161323338353538323661326330316239383562613835363639632600361a7765626835263236303831393138303426776562736f636b6574470000093e76706c617965725f7362616e6e65725f313139393636353039303436305f313139393636353039303436303d313b205f5f79616d69645f7474313d302e3737323039393836313633323930383b205f5f79616d69645f6e65773d43424337354346413933383030303031333033333145413031323745314245423b207564625f67756964646174613d39613735393136666365303934376638616161316461643933303561666633313b207564625f61707069643d353030323b207564625f64657669636569643d775f313134313634393232373139323537383034393b20686469643d346461663233653365333564333034393932643236303061393932343161383731343037636662613b2067616d655f6469643d7732354b543459725643516a6d4b63674d653272574d725a5336365251355741736b373b20677569643d30613764666161323338353538323661326330316239383562613835363639633b205f71696d65695f7575696434323d31613831313038316132323130303438643865656363633166626463653830623238353034633338323b207564625f616e6f7569643d313437313231383037333333323b207564625f616e6f62697a746f6b656e3d4151424535796961754a62663576456450554950395539776f476b3467487751483866535f6e7239474e5758486d3464394d5a626231495143466b636d456746396c7a4c6b48325674524a6a536466485664514a4567485461423574485445755f4f4e62796d545574765a5743727651656946547379506146544257776a6c6c337065567138624a53534e5f4a754a704a66664d5554496b7a626e436450456a792d6350585842434c36445868722d6c496b663648357a6c4b5743526b506838566a76703831433233566a64523774445351764579456a343368436f434567595a6f6f4b494a33583550464f30334837554c6375423432526b574c7874374337396a33427079554a372d73437349747864724f505458355342746e4e306e7a2d65462d746a4a415153707532582d62635a545158656c70565268525051533462475974343755484f4a31484961506d513848336d6d54316f3b205f71696d65695f66696e6765727072696e743d36323833393839366233373235366335623663316662656130633838343161613b205f71696d65695f6833383d61666163623962396438656563636363316662646365383030323030303030353831613831313b20536f756e6456616c75653d302e35303b20616c70686156616c75653d302e38303b20677569643d30613764666161323338353538323661326330316239383562613835363639633b207564625f7569643d313139393537343536343939363b2079797569643d313139393537343536343939363b207564625f70617373706f72743d68795f3134313230303333323b20757365726e616d653d68795f3134313230303333323b207564625f76657273696f6e3d312e303b207564625f6f726967696e3d353b207564625f7374617475733d313b207564625f637265643d436d42534732423148643759686c386e7376366a48555732484b52364b51534e366d6f445763785a686470743578494567777050754c766a686672716768787372474245685f7a3167356b5f46454d596f64365739656e6c4a463855364376645a555571522d6551536551686b526e4b7150584953397975694f5f33795670624d4861485765486c494b305a38506764524761496a6464393b207564625f6f746865723d2537422532326c7425323225334125323231373836393236363734343838253232253243253232697352656d253232253341253232312532322537443b207564625f616363646174613d31353330343734353930393b207564625f62697a746f6b656e3d415143674a6872596d4e5571576f6b44423648464367317076785f4d39506c7a523474506a6d6c503738355956765969425a4c45766531317862656d4b6751724a4f74366a70346e394d62716b4b46363646616d51412d6e6749514e3235696d7674317871764478424233754d636336754a32614346385242583936626242714a634d574e714f485479686c2d5f794266595872344969466966536337647042375050696f636c317839753533686134425956744774747957655f7443317951576c357165313175496a455a5f345a76577869704b423166704a5f7544303458726a432d6f597232567a3436316649794e723851366a4c626457665a3050514b594e564d6d4870314664736e5356617143305f6977747046364f396c354c745a73577258645a3136644b4a3362797a69506f475935586c3566494959593735656b415647624376307038656756787869637a79686a4253303b20685f756e743d313738373331333130313b207564625f70617373646174613d333b20486d5f6c76745f35313730306236633732326635626234636633393930366135393665613431663d313738373233333033392c313738373237393335372c313738373239373432312c313738373331333130343b20484d4143434f554e543d303530324335433036444444354237453b205f5f7961736d69643d302e3737323039393836313633323930383b205f5f79616f6c6479797569643d313139393537343536343939363b205f7961736964733d5f5f726f6f7473696425334443424338434443383541373030303031413735423137343031423446314638443b205f7265705f636e743d323b20687579615f68645f7265705f636e743d353b20486d5f6c7076745f35313730306236633732326635626234636633393930366135393665613431663d313738373331333130373b20687579615f666c6173685f7265705f636e743d31363b206973496e4c697665526f6f6d3d3b20736469643d30556e48556776305f716d6644344b414b6c777a6871555a4c42524a496a536f544e4e694433345161465f49326c6c78546e51564a65555f646b7038436f4a654d766e4d63374b4d416c6c79342d317543797934503149706f6c64373538776a645235645f5658387076776e57566b6e394c7466464a775f516f346b674b72384f5a4844714e6e757767363132734779666c466e31646e4a507774505334386b4a6446314456586c696f4a4f7469744e4b57434d524d73796b4a717a596e6d59613b20687579615f7765625f7265705f636e743d3130363b20687579615f75613d776562683526302e312e3026776562736f636b65745c660365646776000b1300000117519c8f9c2300000117519c8f9c3606e6b58be8af954c5a00ff10042c30ff40ff50ff0b6a00ff10042c30014c5a0c1c20ff306440ff5064660070ff80ff0b690c7c80ff0b790c8300000117519c8f9c990caa0c1c2c0bbc0b8c980ca80c2c3625333232336361393833396133613437303a333232336361393833396133613437303a303a314c5c66206630303265396161653765333838393134313937623561653332653330316135';

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

    _cookie = HuyaLoginManager().cookie;
    _loginUid = int.tryParse(_cookieVal('yyuid')) ??
        (int.tryParse(_cookieVal('udb_uid')) ?? 0);
    _guid = _cookieVal('guid');
    _token = _cookieVal('udb_biztoken');
    _traceId =
        List.generate(16, (_) => '0123456789abcdef'[Random().nextInt(16)]).join();

    onStatus?.call('弹幕连接中…');
    final baseinfo = _buildBaseinfo();
    final urls = [for (final ep in _endpoints) '$ep/?baseinfo=$baseinfo'];

    WebSocket? ws;
    String connectedHost = '';
    for (var i = 0; i < urls.length; i++) {
      if (_closed) return;
      final ep = urls[(_endpointIndex + i) % urls.length];
      try {
        // 关键：与浏览器一致协商 permessage-deflate，va 节点 WUP 通道按压缩会话处理
        ws = await WebSocket.connect(
          ep,
          headers: {
            'Origin': 'https://www.huya.com',
            'User-Agent': _ua,
            'Cache-Control': 'no-cache',
          },
          compression: CompressionOptions.compressionOn,
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

    // 先 wsLaunch（tReq=WSConnectParaInfo），再 Verify + Register
    _send(_wrapWsCmd(
        _withPrefix(_wupBody('launch', 'wsLaunch', {'tReq': _buildLaunchReq()})),
        3,
        ''));
    Timer(const Duration(milliseconds: 600), () {
      if (_closed) return;
      _send(_buildVerifyCookie());
      _send(_buildRegisterGroup());
    });

    _heartTimer?.cancel();
    _heartTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }

  /// baseinfo = WSConnectParaInfo（对齐抓包：sUA/sMid/HUYA_VSDKUA）
  String _buildBaseinfo() {
    final r = Random();
    final mid =
        '${(10000 + r.nextDouble() * 89999).toStringAsFixed(5)},${(10000 + r.nextDouble() * 89999).toStringAsFixed(6)}';
    final info = _TarsWriter();
    info.writeInt(0, _loginUid);
    info.writeString(1, _guid);
    info.writeString(2, _sendHuYaUA);
    info.writeString(3, 'HUYA&ZH&2052');
    info.writeString(4, mid);
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

  /// wsLaunch 的 tReq = WSConnectParaInfo（token/cookie 留空，与抓包一致）
  Uint8List _buildLaunchReq() {
    final r = Random();
    final mid =
        '${(10000 + r.nextDouble() * 89999).toStringAsFixed(5)},${(10000 + r.nextDouble() * 89999).toStringAsFixed(6)}';
    final req = _TarsWriter();
    req.writeInt(0, _loginUid);
    req.writeString(1, _guid);
    req.writeString(2, _sendHuYaUA);
    req.writeString(3, 'HUYA&ZH&2052');
    req.writeString(4, mid);
    req.writeInt(6, 0);
    req.writeString(7, '');
    req.writeString(8, '');
    req.writeString(9, '');
    req.writeMap(10, const {
      'HUYA_NET': '0',
      'HUYA_VSDKUA': _sendHuYaUA,
    });
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
    cmd.writeInt(2, ++_reqId);
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

  // ================= 发送弹幕（replay 差分 + sMD5 三变体） =================
  Future<bool> sendDanmaku(String text) async {
    if (_loginUid <= 0) return false;
    if (!_verified || !_registered) {
      _dbgPush('未认证/未注册');
      return false;
    }
    try {
      // 差分测试：输入 replay 时原样重放抓包帧
      if (text == 'replay') {
        _pendingDanmaku = '测试';
        _send(_hexToBytes(_replayHex));
        _dbgPush('REPLAY 原始帧已发');
        return true;
      }

      _pendingDanmaku = text;
      final req = _buildSendReq(text);
      final body = _wupBody('liveui', 'sendMessage', {'tReq': req});
      final framed = _withPrefix(body);

      // 变体1：sMD5 = md5(带前缀整体)
      _send(_wrapWsCmd(framed, 3, md5.convert(framed).toString()));
      _dbgPush('V1 md5(full) 已发');

      Timer(const Duration(milliseconds: 1500), () {
        if (_closed || _pendingDanmaku == null) return;
        // 变体2：sMD5 = md5(去掉前缀的WUP体)
        _send(_wrapWsCmd(framed, 3, md5.convert(body).toString()));
        _dbgPush('V2 md5(body) 补发');
      });
      Timer(const Duration(milliseconds: 3000), () {
        if (_closed || _pendingDanmaku == null) return;
        // 变体3：sMD5 = 空串
        _send(_wrapWsCmd(framed, 3, ''));
        _dbgPush('V3 空md5 补发');
      });
      return true;
    } catch (e) {
      _dbgPush('发送异常:$e');
      return false;
    }
  }

  /// SendMessageReq（逐字节对齐抓包）
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

  /// WUP 体（不含长度前缀）
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

  /// 4 字节大端长度前缀
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

  /// WebSocketCommand（对齐抓包：无 tag2，traceId 尾缀 :0:1，sMD5 参数化）
  Uint8List _wrapWsCmd(Uint8List vData, int cmdType, String sMd5) {
    final cmd = _TarsWriter();
    cmd.writeInt(0, cmdType);
    cmd.writeBytes(1, vData);
    cmd.writeString(3, '$_traceId:$_traceId:0:1');
    cmd.writeInt(4, 0);
    cmd.writeInt(5, 0);
    cmd.writeString(6, sMd5);
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
          // 未知命令全量打印：抓出服务器对 WUP 的真实回应
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
