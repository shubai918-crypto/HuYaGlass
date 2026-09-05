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
  final bool isGift;
  final String giftName;
  final int giftCount;
  final int comboCount;

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
    this.isGift = false,
    this.giftName = '',
    this.giftCount = 1,
    this.comboCount = 0,
  });

  static const kBadgeManager =
      'https://livewebbs2.msstatic.com/newfangguan_3.png';

  static const Map<String, String> kGiftIcons = {
    '虎粮': 'https://fileserver.cdn.huya.com/admin_gift_merge/e05e0b09162a4e6c9e4ea484e180d600/36.png',
    '热火': 'https://fileserver.cdn.huya.com/admin_gift_merge/0fdaa91cab6249699d816a4e4d1b2ebb/36.png',
    '超粉虎粮': 'https://fileserver.cdn.huya.com/admin_gift_merge/9041bf229f8d4218aac391987d3854d8/36.png',
    '小月亮': 'https://fileserver.cdn.huya.com/admin_gift_merge/05fd9e5045f24cbb8ac813c31a8f4e0b/36.png',
  };
}

class VipUser {
  final String nickname;
  final String avatar;
  final int uid;
  final int guardLevel;
  final String guardIcon;
  final int nobleLevel;
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

  static const Map<String, String> _builtinEmotes = {
    '[666]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141729267685_pic.png',
    '[打呼]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141739514550_pic.png',
    '[大哭]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141716134667_pic.png',
    '[大笑]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141715551855_pic.png',
    '[害羞]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141734805267_pic.png',
    '[笑哭]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141744424368_pic.png',
    '[狗头]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16164185817771_pic.png',
    '[震惊]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141737604305_pic.png',
    '[整不会了6]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/abee3a09a3ca49e4b4e567886eb0f5c9/expressconfig/steam_3.png',
    '[你是我的哥]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/dda720298ab146419718397f97dcb2eb/expressconfig/steam_3.png',
    '[盯]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/27d952f79d2a48859eca9ebaf1146f09/expressconfig/steam_3.png',
    '[不是哥们2]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/809a798714164c70a3f24feb090043b4/expressconfig/steam_3.png',
    '[婉拒了哈]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1656062162steam_3.png',
    '[这不好吧]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1656062177steam_3.png',
    '[他在CPU你]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/78f30039a103416cb7e2e5394138e0ea/expressconfig/steam_3.png',
    '[注意看1]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/88187b37451a4ab9a98eb3fba1fb3463/expressconfig/steam_3.png',
    '[厚礼蟹]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/e9206baa27e341e0b556de168c6003d6/expressconfig/steam_3.png',
    '[真服了老六]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/61d215d04b7145908d0af419f0111aec/expressconfig/steam_3.png',
    '[泰酷辣]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/e61973807356460a83adc9568799a938/expressconfig/steam_3.png',
    '[几个菜啊]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/b638ab65dfad4a149e20feebda223ba7/expressconfig/steam_3.png',
    '[街溜子]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/c4586ceb173340a19ea86a64d11792cb/expressconfig/steam_3.png',
    '[我是学生]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/f1a8ec12f6a746a2ad4f4df389876d6b/expressconfig/steam_3.png',
    '[不会吧]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/f9f7caf65ef9419f8ee967e01e6dccab/expressconfig/steam_3.png',
    '[恭喜发财2]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/58f65d52b10b4187815de239362565ba/expressconfig/steam_3.png',
    '[蒜鸟]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/5293fc1adc0c4820aad8d2ce4eabc387/expressconfig/steam_3.png',
    '[夯爆了]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/2a39fb8007c34591ae1999282c72b257/expressconfig/steam_3.png',
    '[真的六]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/023c6ec6575c4952ae77c4bd74d2a72f/expressconfig/steam_3.png',
    '[俺不中嘞]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/c0a00ac14515474f8f65101132964e76/expressconfig/steam_3.png',
    '[这瓜保熟吗]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1629978877steam_3.png',
    '[我不理解]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1629978857steam_3.png',
    '[你好有本领啊]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1633760698steam_3.png',
  };

  static final Map<String, String> emoteRegistry = {};
  static bool _emoteSeeded = false;
  static void _seedBuiltinEmotes() {
    if (_emoteSeeded) return;
    _emoteSeeded = true;
    _builtinEmotes.forEach((k, v) => emoteRegistry.putIfAbsent(k, () => _fixEmoteUrl(v)));
  }

  static String _fixEmoteUrl(String url) {
    const bad = 'steam.png';
    if (url.endsWith(bad)) return url.substring(0, url.length - bad.length) + 'steam_3.png';
    return url;
  }

  static bool isBigEmote(String url) =>
      !url.contains('web_base_material') && !url.contains('expressconfig');

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

  final Map<String, int> _recentKeys = {};
  final Map<String, int> _comboCount = {};
  final Map<String, int> _comboTime = {};

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

  final List<VipUser> guardList = [];
  final List<VipUser> vipList = [];
  final StreamController<List<VipUser>> _vipController =
      StreamController<List<VipUser>>.broadcast();
  Stream<List<VipUser>> get vipStream => _vipController.stream;

  String _cookieVal(String name) =>
      RegExp('$name=([^;]+)').firstMatch(_cookie)?.group(1)?.trim() ?? '';

  String _randHex(int n) =>
      List.generate(n, (_) => '0123456789abcdef'[Random().nextInt(16)]).join();

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
    _recentKeys.clear();
    _comboCount.clear();
    _comboTime.clear();

    _seedBuiltinEmotes();
    if (emoteRegistry.isNotEmpty) {
      Future.delayed(
          const Duration(milliseconds: 100), () => onEmoteReady?.call());
    }

    _cookie = HuyaLoginManager().cookie;
    _loginUid = int.tryParse(_cookieVal('yyuid')) ??
        (int.tryParse(_cookieVal('udb_uid')) ?? 0);
    _guid = _cookieVal('guid');
    _traceId = _randHex(16);

    onStatus?.call('弹幕连接中…');
    final baseinfo = _buildBaseinfo();
    final hosts = await _preferredHosts();
    final urls = [
      for (final h in hosts) 'wss://$h/?baseinfo=${Uri.encodeComponent(baseinfo)}'
    ];

    WebSocket? ws;
    String connectedHost = '';
    for (final ep in urls) {
      if (_closed) return;
      try {
        ws = await WebSocket.connect(ep,
            headers: {
              'Origin': 'https://www.huya.com',
              'User-Agent': _ua,
              'Cache-Control': 'no-cache',
            },
            compression: CompressionOptions.compressionDefault)
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
      if (!_closed) _sendLaunch();
    });
    Timer(const Duration(milliseconds: 600), () {
      if (!_closed) _sendRegister();
    });
    Timer(const Duration(milliseconds: 900), () {
      if (!_closed) _sendSubscribeHistory();
    });
    Timer(const Duration(milliseconds: 1200), () {
      if (!_closed) _fetchEmoticonPackage();
    });
    Timer(const Duration(milliseconds: 1500), () {
      if (!_closed) _sendRctTimedMessage();
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

  void _sendLaunch() {
    final li = _TarsWriter();
    li.writeString(0, _guid);
    li.writeInt(1, 0);
    li.writeString(3, '${_randHex(16)}:${_randHex(16)}:0:0');
    final body = _wupBody('launch', 'wsTimeSync', {'tReq': _treq(li.toBytes())});
    _send(_wrapWsCmd(_withPrefix(body), 3));
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

  void _sendRegister() {
    final req = _TarsWriter();
    req.writeStringList(0, ['live:$_ayyuid', 'chat:$_ayyuid', 'comm:vipbar_$_ayyuid']);
    req.writeString(1, '');
    final cmd = _TarsWriter();
    cmd.writeInt(0, 16);
    cmd.writeBytes(1, req.toBytes());
    cmd.writeInt(2, ++_reqId);
    _send(cmd.toBytes());
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
    info.writeInt(8, 0);
    info.writeString(9, '');
    info.writeMap(10, const {'HUYA_NET': '0', 'HUYA_VSDKUA': _sendHuYaUA});
    return base64Encode(info.toBytes());
  }

  void _sendSubscribeHistory() {
    _sendSub33Groups({
      'live:$_ayyuid': const {
        6111: 12, 6479: 1, 6480: 1, 6481: 1, 6892: 6,
        6973: 1, 6974: 1, 6975: 1, 8006: 2,
      },
      'comm:vipbar_${_ayyuid}': const {6210: 2, 6893: 1},
      'chat:$_ayyuid': const {6110: 2, 66: 1, 67: 5, 69: 5},
    });
    _sendSub33Groups({
      'live:$_ayyuid': const {6111: 28, 6483: 1},
      'chat:$_ayyuid': const {6110: 1, 67: 5, 69: 2},
    });
    _dbgPush('Register(vipbar) 已发');
  }

  void _sendSub33Groups(Map<String, Map<int, int>> groups) {
    final body = _TarsWriter();
    body.writeString(0, 'HUYA&ZH&2052');
    body.writeString(1, _guid);
    body.writeInt(2, 0);
    body.writeInt(3, 0);
    body.writeGroupMap(6, groups);
    body.writeInt(7, 0);
    body.writeInt(8, 0);
    body.writeInt(2, 0);
    body.writeString(3, '');
    body.writeInt(4, 0);
    body.writeInt(5, 0);
    body.writeString(6, '');
    final cmd = _TarsWriter();
    cmd.writeInt(0, 33);
    cmd.writeBytes(1, body.toBytes());
    cmd.writeInt(2, ++_reqId);
    _send(cmd.toBytes());
    _dbgPush('订阅33 已发');
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

  void _fetchEmoticonPackage() {
    try {
      final myUid = _loginUid > 0 ? _loginUid : _ayyuid;
      final uaInfo = _TarsWriter();
      uaInfo.writeInt(0, myUid);
      uaInfo.writeString(1, _guid);
      uaInfo.writeString(3, _emoHuYaUA);
      uaInfo.writeString(4, _cookie);
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
      uaInfo.writeString(3, _sendHuYaUA);
      uaInfo.writeString(4, _cookie);
      uaInfo.writeString(6, 'edg');
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
      final body = _wupBody('mobileui', 'getRctTimedMessage', {'tReq': req.toBytes()});
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

  Uint8List _treq(Uint8List s) {
    final o = BytesBuilder();
    o.addByte(0x0A); o.add(s); o.addByte(0x0B);
    return o.toBytes();
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
      final cmdRaw = fields[0];
      final cmdType = cmdRaw is int ? cmdRaw : -1;
      final vData = fields[1];
      if (vData is! List) {
        onStatus?.call('收包$_recvCount cmd=$cmdType');
        return;
      }
      final payload = Uint8List.fromList(vData.map((e) => (e as int) & 0xFF).toList());

      if (cmdType == 11) {
        final f = _TarsReader(payload).readFields();
        final f0 = f[0];
        if (f0 is int && f0 == 0) _verified = true;
        _dbgPush('Verify iValidate=$f0');
      } else if (cmdType == 17) {
        final f = _TarsReader(payload).readFields();
        final f0 = f[0];
        if (f0 is int && f0 == 0) _registered = true;
        _dbgPush('Register iResCode=$f0');
      } else if (cmdType == 33) {
        _dbgPush('分组状态(33)');
      } else if (cmdType == 34) {
        final f = _TarsReader(payload).readFields();
        final f0 = f[0];
        _dbgPush('Register34 iResCode=$f0');
      } else if (cmdType == 4) {
        _handleWupRsp(payload);
      } else if (cmdType == 21) {
      } else if (cmdType == 22 || cmdType == 7) {
        final s = utf8.decode(payload, allowMalformed: true);
        if (s.contains('vipbar')) {
          if (cmdType == 22) _parseGuardPush(payload); else _parseVipPush(payload);
        } else {
          _handleMsgPushUnified(payload);
        }
      } else {
        _handleMsgPushUnified(payload);
      }
      onStatus?.call('收包$_recvCount cmd=$cmdType');
    } catch (_) {}
  }

  void _parseGuardPush(Uint8List p) {
    final temp = <VipUser>[];
    _walkVip(p, temp);
    guardList.clear();
    guardList.addAll(temp.where((e) => e.guardIcon.isNotEmpty));
    _vipController.add(List.from(guardList));
    _dbgPush('守护 ${guardList.length} 人');
  }

  void _parseVipPush(Uint8List p) {
    final temp = <VipUser>[];
    _walkVip(p, temp);
    vipList.clear();
    vipList.addAll(temp);
    _vipController.add(List.from(vipList));
    _dbgPush('贵宾 ${vipList.length} 人');
  }

  static bool _isJunkStr(String s) {
    if (s.isEmpty) return true;
    if (s.startsWith('/') || s.startsWith('http') || s.startsWith('comm:')) return true;
    if (s.contains('.mp4') || s.contains('.png') || s.contains('.gif')) return true;
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(s)) return true;
    return false;
  }

  static bool _isGuardTitle(String s) => s == '剑士' || s == '骑士' || s == '领主';

  void _walkVip(Uint8List p, List<VipUser> list) {
    void walk(dynamic node, int depth) {
      if (depth > 12) return;
      if (node is Map<int, Object?>) {
        bool hasAvatar = false;
        for (final v in node.values) {
          if (v is String && v.startsWith('http') && v.contains('avatar')) { hasAvatar = true; break; }
        }
        if (hasAvatar) {
          final strPool = <String>[];
          String avatar = '', gIcon = '', nIcon = '', pIcon = '', fansName = '';
          int uid = 0, fansLevel = 0, managerType = 0;
          void scan(dynamic n, int d) {
            if (d > 6) return;
            if (n is String) {
              if (n.startsWith('http')) {
                if (avatar.isEmpty && n.contains('avatar')) { avatar = n; return; }
                if (n.contains('guardrank') && gIcon.isEmpty) { gIcon = n; return; }
                if ((n.contains('yepai') || n.contains('guiyepai')) && nIcon.isEmpty) { nIcon = n; return; }
                if ((n.contains('Pendant') || n.contains('pendant') || n.contains('PendantInfoZip') || n.contains('fenzuan') || n.contains('diamond') || n.contains('file_')) && pIcon.isEmpty) { pIcon = n; return; }
              } else if (!_isJunkStr(n) && !_isGuardTitle(n)) {
                strPool.add(n);
              }
            } else if (n is Map<int, Object?>) {
              final n0 = n[0]; final n3 = n[3]; final n4 = n[4]; final n7 = n[7];
              if (n0 is int && n0 > 100000 && uid == 0) uid = n0;
              if (n3 is String && n4 is int && n4 >= 1 && n4 <= 99 && fansName.isEmpty && !_isGuardTitle(n3)) { fansName = n3; fansLevel = n4; }
              if (n7 is int && n7 > 0 && n7 <= 3 && managerType == 0) managerType = n7;
              n.values.forEach((v) => scan(v, d + 1));
            } else if (n is List) {
              if (n.isNotEmpty && n.first is int) {
                try {
                  final parsed = _TarsReader(Uint8List.fromList(n.cast<int>())).readFields();
                  if (parsed.isNotEmpty) { scan(parsed, d + 1); return; }
                } catch (_) {}
              }
              n.forEach((v) => scan(v, d + 1));
            }
          }
          scan(node, 0);
          String nick = '';
          for (final s in strPool) { if (s.length > nick.length) nick = s; }
          int gl = 0;
          if (gIcon.contains('/1.png')) gl = 1;
          else if (gIcon.contains('/2.png')) gl = 2;
          else if (gIcon.contains('/3.png')) gl = 3;
          if (nick.isNotEmpty && avatar.isNotEmpty && !list.any((e) => e.nickname == nick)) {
            list.add(VipUser(
                nickname: nick, avatar: avatar, uid: uid,
                guardLevel: gl, guardIcon: gIcon,
                nobleIcon: nIcon, fansName: fansName, fansLevel: fansLevel,
                managerType: managerType, pendantIcon: pIcon));
          }
          return;
        }
        node.values.forEach((v) => walk(v, depth + 1));
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            final parsed = _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
            if (parsed.isNotEmpty) { walk(parsed, depth + 1); return; }
          } catch (_) {}
        }
        node.forEach((v) => walk(v, depth + 1));
      }
    }
    walk(_TarsReader(p).readFields(), 0);
  }

  Map<int, Object?> _readWupFields(List<int> bytes) {
    var start = 0;
    if (bytes.length > 4) {
      final prefix = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      if (prefix == bytes.length) start = 4;
    }
    return _TarsReader(Uint8List.fromList(bytes.sublist(start))).readFields();
  }

  void _handleWupRsp(List<int> bytes) {
    try {
      final f = _readWupFields(bytes);
      final servant = '${f[5] ?? ''}';
      final func = '${f[6] ?? ''}';

      if (servant == 'wupui' && func == 'getExpressionEmoticonPackage') {
        int cnt = 0;
        void walk(dynamic node, int depth) {
          if (depth > 14) return;
          if (node is Map<int, Object?>) {
            String? name; String? url;
            for (final v in node.values) {
              if (v is String) {
                if (name == null && v.startsWith('[')) name = v;
                else if (url == null && v.startsWith('http')) url = v;
              }
            }
            if (name != null && url != null) { emoteRegistry[name] = _fixEmoteUrl(url); cnt++; return; }
            node.values.forEach((v) => walk(v, depth + 1));
          } else if (node is List) {
            if (node.isNotEmpty && node.first is int) {
              try {
                final parsed = _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
                if (parsed.isNotEmpty) { walk(parsed, depth + 1); return; }
              } catch (_) {}
            }
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
            final n3 = node[3]; final n0 = node[0];
            if (n3 is String && n0 is Map<int, Object?>) msgNode = node;
            else if (n0 is Map<int, Object?>) {
              final n03 = n0[3];
              if (n03 is String) msgNode = n0;
            }
            if (msgNode != null && _emitFromFields(msgNode, history: true)) { n++; return; }
            node.values.forEach((v) => collect(v, depth + 1));
          } else if (node is List) {
            if (node.isNotEmpty && node.first is int) {
              try {
                final parsed = _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
                if (parsed.isNotEmpty) collect(parsed, depth + 1);
              } catch (_) {}
              return;
            }
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
        final inner = _TarsReader(Uint8List.fromList(sb.map((e) => (e as int) & 0xFF).toList())).readFields();
        final map = inner[0];
        if (map is List) {
          for (var i = 0; i + 1 < map.length; i += 2) {
            if ('${map[i]}' == 'tRsp' && map[i + 1] is List) {
              final rspBytes = Uint8List.fromList((map[i + 1] as List).map((e) => (e as int) & 0xFF).toList());
              final rsp = _TarsReader(rspBytes).readFields();
              final r0 = rsp[0];
              ret = r0 is int ? r0 : -99;
              if (servant == 'launch' && ret == 0) _parseLaunchRsp(rsp);
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
      final v = entry.value;
      if (v is List && v.isNotEmpty && v.first is String) {
        for (final item in v) {
          if (item is String) {
            if (item.contains('huya.com')) newHosts.add(item);
            else if (item.contains(':')) newHosts.add(item.split(':').first);
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
        if (v is List && v.isNotEmpty && v.first is Map<int, Object?>) {
          for (final item in v) {
            if (item is Map<int, Object?>) {
              final uriRaw = item[0];
              final uri = uriRaw is int ? uriRaw : 1400;
              final raw = item[1];
              if (raw is List) _routePush(uri, raw.map((e) => (e as int) & 0xFF).toList());
              else if (raw is Uint8List) _routePush(uri, raw);
            }
          }
          return;
        }
      }
      final uriRaw = f[1];
      final uri = uriRaw is int ? uriRaw : 1400;
      final raw = f[2];
      if (raw is List) { _routePush(uri, raw.map((e) => (e as int) & 0xFF).toList()); return; }
      else if (raw is Uint8List) { _routePush(uri, raw); return; }
      final f3 = f[3]; final f0 = f[0];
      if (f3 is String || f0 is Map<int, Object?>) _decodeDanmaku(payload);
    } catch (_) {}
  }

  void _routePush(int uri, List<int> payload) {
    if (uri == 1400) _decodeDanmaku(payload);
    else if (uri == 6500 || uri == 6501 || uri == 6502) _parseGiftPush(payload);
    else if (uri == 8006) {
      try {
        final f = _TarsReader(Uint8List.fromList(payload)).readFields();
        final pop = f[0];
        if (pop is int && pop > 0) onPopularity?.call(pop);
      } catch (_) {}
    }
  }

void _parseGiftPush(List<int> payload) {
    try {
      final f = _TarsReader(Uint8List.fromList(payload)).readFields();
      final presenter = f[5] is String ? (f[5] as String) : ''; // 主播名
      var sender = f[6] is String ? (f[6] as String) : '';       // ★ 送礼人=tag6

      final strs = <String>[];
      void walk(dynamic n, int d) {
        if (d > 8) return;
        if (n is String) {
          if (n.isNotEmpty && !n.startsWith('http')) strs.add(n);
        } else if (n is Map<int, Object?>) {
          n.values.forEach((v) => walk(v, d + 1));
        } else if (n is List) {
          if (n.isNotEmpty && n.first is int) {
            try {
              final p = _TarsReader(Uint8List.fromList(n.cast<int>())).readFields();
              if (p.isNotEmpty) { walk(p, d + 1); return; }
            } catch (_) {}
          }
          n.forEach((v) => walk(v, d + 1));
        }
      }
      walk(f, 0);

      bool isId(String s) => s.length > 20 || RegExp(r'^[0-9A-F]{16,}$').hasMatch(s);

      // sender 兜底：第一个 非主播、非长id 的串
      if (sender.isEmpty || sender == presenter) {
        for (final s in strs) {
          if (s.isNotEmpty && s != presenter && !isId(s)) { sender = s; break; }
        }
      }

      // 礼物名：优先命中内置图，否则取 非主播/非发送者/非id 的短串
      String giftName = '';
      for (final s in strs) {
        if (DanmakuMessage.kGiftIcons.containsKey(s)) { giftName = s; break; }
      }
      if (giftName.isEmpty) {
        for (final s in strs) {
          if (s.isNotEmpty && s != presenter && s != sender && !isId(s) && s.length <= 8) { giftName = s; break; }
        }
      }
      if (giftName.isEmpty || sender.isEmpty) return;

      final key = '$sender|$giftName';
      final now = DateTime.now().millisecondsSinceEpoch;
      int combo = 1;
      if (_comboTime[key] != null && now - _comboTime[key]! < 10000) {
        combo = (_comboCount[key] ?? 1) + 1;
      }
      _comboCount[key] = combo;
      _comboTime[key] = now;

      _controller.add(DanmakuMessage(
        nickname: sender, content: '', fontColor: 0xFFFFB25E,
        isGift: true, giftName: giftName, giftCount: 1, comboCount: combo,
      ));
    } catch (_) {}
  }

  bool _decodeDanmaku(List<int> payload) {
    try {
      return _emitFromFields(_TarsReader(Uint8List.fromList(payload)).readFields());
    } catch (_) {
      return false;
    }
  }

bool _emitFromFields(Map<int, Object?> fields, {bool history = false}) {
    Map<int, Object?> msg = fields;
    final f3 = fields[3]; final f0 = fields[0];
    if (f3 is! String && f0 is Map<int, Object?>) {
      final f03 = f0[3];
      if (f03 is String) msg = f0;
    }
    final content = msg[3];
    if (content is! String || content.isEmpty) return false;
    var sender = msg[0];
    if (sender is! Map<int, Object?>) return false;
    final s0 = sender[0];
    if (s0 is Map<int, Object?>) sender = s0;
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

    final key = '$nick|$content';
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentKeys.removeWhere((k, t) => now - t > 8000);
    if (_recentKeys.containsKey(key)) return true;
    _recentKeys[key] = now;

    int color = 0;
    int findColor(dynamic node, int depth) {
      if (node == null || depth > 4) return 0;
      if (node is Map<int, Object?>) {
        final c0 = node[0];
        if (c0 is int && c0 > 0 && c0 != 0xFFFFFF && c0 <= 0xFFFFFF && c0 >= 0x100) return c0;
        for (final v in node.values) {
          final c = findColor(v, depth + 1);
          if (c != 0) return c;
        }
      } else if (node is int) {
        if (node >= 0x100 && node <= 0xFFFFFF && node != 0xFFFFFF) return node;
      }
      return 0;
    }
    for (final k in const [6, 5]) {
      color = findColor(msg[k], 0);
      if (color != 0) break;
    }

    int managerType = 0;
    final mt = msg[7];
    if (mt is int && mt > 0 && mt <= 3) managerType = mt;

    String fansName = ''; int fansLevel = 0;
    bool isName(dynamic s) => s is String && s.isNotEmpty && !s.startsWith('http') && s.length <= 12 && s != nick && s != content && !_isGuardTitle(s);
    void findFans(dynamic node, int depth) {
      if (fansName.isNotEmpty || depth > 8) return;
      if (node is Map<int, Object?>) {
        final n3 = node[3]; final n4 = node[4]; final n2 = node[2]; final n0 = node[0];
        if (isName(n3) && n4 is int && n4 >= 1 && n4 <= 99) { fansName = n3 as String; fansLevel = n4; return; }
        if (isName(n2) && n3 is int && n3 >= 1 && n3 <= 99 && n0 is int) { fansName = n2 as String; fansLevel = n3; return; }
        node.values.forEach((v) => findFans(v, depth + 1));
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            final inner = _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
            if (inner.isNotEmpty) findFans(inner, depth + 1);
          } catch (_) {}
        } else {
          node.forEach((v) => findFans(v, depth + 1));
        }
      }
    }
    findFans(msg, 0);

    final badges = <String>[];
    void findBadges(dynamic node, int depth) {
      if (depth > 8) return;
      if (node is Map<int, Object?>) {
        node.values.forEach((v) => findBadges(v, depth + 1));
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try { findBadges(_TarsReader(Uint8List.fromList(node.cast<int>())).readFields(), depth + 1); } catch (_) {}
        } else {
          node.forEach((v) => findBadges(v, depth + 1));
        }
      } else if (node is String && node.startsWith('http')) {
        if (node.contains('guiyepai') || node.contains('Pendant') || node.contains('pendant') || node.contains('PendantInfoZip') || node.contains('fenzuan') || node.contains('fengzuan') || node.contains('fangguan') || node.contains('diamond') || node.contains('file_')) {
          if (!badges.contains(node)) badges.add(node);
        }
      }
    }
    findBadges(msg, 0);

    final ordered = <String>[];
    for (final u in badges) {
      if (u.contains('guiyepai')) ordered.add(u.contains('_3.png') ? u : u.replaceAll('guiyepai.png', 'guiyepai_3.png'));
    }
    for (final u in badges) {
      if (u.contains('Pendant') || u.contains('pendant') || u.contains('fenzuan') || u.contains('fengzuan') || u.contains('diamond') || u.contains('file_')) ordered.add(u);
    }
    for (final u in badges) {
      if (u.contains('fangguan')) ordered.add(u);
    }

    _controller.add(DanmakuMessage(
      nickname: nick, content: content,
      fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000),
      avatar: avatar, uid: uidVal,
      fansName: fansName, fansLevel: fansLevel,
      managerType: managerType, badgeUrls: ordered,
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
      final n5 = fields[5]; final n6 = fields[6];
      final nick = n5 is String ? n5 : '';
      final content = n6 is String ? n6 : '';
      if (nick.isEmpty || content.isEmpty || content == nick) return;
      String avatar = '';
      for (final v in fields.values) {
        if (v is String && v.startsWith('http')) { avatar = v; break; }
      }
      _controller.add(DanmakuMessage(nickname: nick, content: content, avatar: avatar, isHistory: true));
    } catch (_) {}
  }
}

class _TarsWriter {
  final BytesBuilder _b = BytesBuilder();
  void _head(int tag, int type) {
    if (tag < 15) { _b.addByte((tag << 4) | type); }
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
  void _intValue(int v) { final t = _intType(v); if (t == 12) { _b.addByte(0x0C); return; } _b.addByte(t); _add(v, [1, 2, 4, 8][t]); }
  void writeInt(int tag, int v) { final t = _intType(v); _head(tag, t); if (t == 12) return; _add(v, [1, 2, 4, 8][t]); }
  void writeString(int tag, String s) {
    final b = utf8.encode(s);
    if (b.length < 256) { _head(tag, 6); _b.addByte(b.length); }
    else { _head(tag, 7); _add(b.length, 4); }
    _b.add(b);
  }
  void writeStringList(int tag, List<String> items) { _head(tag, 9); _intValue(items.length); for (final s in items) writeString(0, s); }
  void writeListInt(int tag, List<int> items) { _head(tag, 9); _intValue(items.length); for (final v in items) writeInt(0, v); }
  void writeIntIntMap(int tag, Map<int, int> m) { _head(tag, 8); _intValue(m.length); m.forEach((k, v) { writeInt(0, k); writeInt(1, v); }); }
  void writeGroupMap(int tag, Map<String, Map<int, int>> m) {
    _head(tag, 8);
    _intValue(m.length);
    m.forEach((group, ids) {
      writeString(0, group);
      writeIntIntMap(1, ids);
    });
  }
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
  int _readIntN(int n) { var v = 0; for (var i = 0; i < n; i++) v = (v << 8) | _d[_pos++]; return (v << (64 - 8 * n)) >> (64 - 8 * n); }
  int _readValueInt() { final t = _byte(); if (t == 12) return 0; return _readIntN([1, 2, 4, 8][t]); }
  Map<int, Object?> readFields() {
    final m = <int, Object?>{};
    while (hasMore) {
      final h = _byte(); final type = h & 0x0F;
      if (type == 11) return m;
      var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte();
      m[tag] = _readValue(type);
    }
    return m;
  }
  Object? _readValue(int type) {
    if (type <= 3) return _readIntN([1, 2, 4, 8][type]);
    if (type == 12) return 0;
    if (type == 6) { final n = _byte(); final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true); _pos += n; return s; }
    if (type == 7) { final n = _readIntN(4); final s = utf8.decode(_d.sublist(_pos, _pos + n), allowMalformed: true); _pos += n; return s; }
    if (type == 13) { _byte(); final n = _readValueInt(); final b = _d.sublist(_pos, _pos + n); _pos += n; return b; }
    if (type == 9) { final size = _readValueInt(); final l = <Object?>[]; for (var i = 0; i < size; i++) { final h = _byte(); var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); l.add(_readValue(h & 0x0F)); } return l; }
    if (type == 8) { final size = _readValueInt(); final l = <Object?>[]; for (var i = 0; i < size * 2; i++) { final h = _byte(); var tag = (h >> 4) & 0x0F; if (tag == 15) tag = _byte(); l.add(_readValue(h & 0x0F)); } return l; }
    if (type == 10) return readFields();
    return null;
  }
}
