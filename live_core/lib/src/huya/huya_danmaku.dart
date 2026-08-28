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

  /// 房管徽章（自带 _3，可直接加载）
  static const kBadgeManager =
      'https://livewebbs2.msstatic.com/newfangguan_3.png';
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

  // ================= 内置表情表（源自接收数据） =================
  // 默认包用 _pic.png（正常）；express 包统一 steam_3.png（steam.png 加载不出）
  static const Map<String, String> _builtinEmotes = {
    // ---- 默认包 ----
    '[666]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141729267685_pic.png',
    '[打呼]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141739514550_pic.png',
    '[滑稽]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141739087048_pic.png',
    '[难受]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141738689917_pic.png',
    '[亲亲]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141738398631_pic.png',
    '[无辜]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141738020039_pic.png',
    '[震惊]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141737604305_pic.png',
    '[大笑]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141715551855_pic.png',
    '[送花]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141715844572_pic.png',
    '[偷笑]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_15790913779295_pic.png',
    '[大哭]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141716134667_pic.png',
    '[嘿哈]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141728933000_pic.png',
    '[疑问]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141729809356_pic.png',
    '[赞]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16142231359365_pic.png',
    '[可爱]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141731673076_pic.png',
    '[开心]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141732333718_pic.png',
    '[害羞]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141734805267_pic.png',
    '[笑哭]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141744424368_pic.png',
    '[调皮]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16141743387129_pic.png',
    '[狗头]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16164185817771_pic.png',
    '[就这？]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16164186362506_pic.png',
    '[OK]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16100992014714_pic.png',
    '[爱心]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16104371440086_pic.png',
    '[吃瓜]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16104410395955_pic.png',
    '[哈哈大笑]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16104451098331_pic.png',
    '[么么哒]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16104459735817_pic.png',
    '[裂开了]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16104458758417_pic.png',
    '[流泪]': 'http://cdnfile2.msstatic.com/cdnfile/material_manage/web_base_material_16104459270039_pic.png',
    // ---- 梗表情（express，steam_3.png） ----
    '[不是哥们2]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/809a798714164c70a3f24feb090043b4/expressconfig/steam_3.png',
    '[神金3]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/1d5d44528d2544cabd96063d899842e8/expressconfig/steam_3.png',
    '[婉拒了哈]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1656062162steam_3.png',
    '[这不好吧]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1656062177steam_3.png',
    '[他在CPU你]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/78f30039a103416cb7e2e5394138e0ea/expressconfig/steam_3.png',
    '[注意看1]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/88187b37451a4ab9a98eb3fba1fb3463/expressconfig/steam_3.png',
    '[整不会了6]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/abee3a09a3ca49e4b4e567886eb0f5c9/expressconfig/steam_3.png',
    '[你是我的哥]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/dda720298ab146419718397f97dcb2eb/expressconfig/steam_3.png',
    '[厚礼蟹]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/e9206baa27e341e0b556de168c6003d6/expressconfig/steam_3.png',
    '[真服了老六]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/61d215d04b7145908d0af419f0111aec/expressconfig/steam_3.png',
    '[泰酷辣]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/e61973807356460a83adc9568799a938/expressconfig/steam_3.png',
    '[几个菜啊]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/b638ab65dfad4a149e20feebda223ba7/expressconfig/steam_3.png',
    '[街溜子]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/c4586ceb173340a19ea86a64d11792cb/expressconfig/steam_3.png',
    '[我是学生]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/f1a8ec12f6a746a2ad4f4df389876d6b/expressconfig/steam_3.png',
    '[兔个好运1]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/937dc6416c574022bcfa8e5bca22518c/expressconfig/steam_3.png',
    '[不会吧]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/f9f7caf65ef9419f8ee967e01e6dccab/expressconfig/steam_3.png',
    '[恭喜发财2]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/58f65d52b10b4187815de239362565ba/expressconfig/steam_3.png',
    '[指哪打哪]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/bdc237fe5f64411cbff3039933daa294/expressconfig/steam_3.png',
    '[心里有数]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/27ae54d51eba4f769bcbb51aa6ca3270/expressconfig/steam_3.png',
    '[你应得的]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/5a63dc48a52a497d8410c86ed754592f/expressconfig/steam_3.png',
    '[顶级]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/bdd03cdbd4f94cf7afe7077c07b9cea4/expressconfig/steam_3.png',
    '[有实力的]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/c49b89484a1d4476b307fc163ff721a3/expressconfig/steam_3.png',
    '[蒜鸟]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/5293fc1adc0c4820aad8d2ce4eabc387/expressconfig/steam_3.png',
    '[几个意思]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/a25c121f18114c8390f850669f9d8ea9/expressconfig/steam_3.png',
    '[夯爆了]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/2a39fb8007c34591ae1999282c72b257/expressconfig/steam_3.png',
    '[包的兄弟]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/883edb56e08b443cad098a8173b0f80d/expressconfig/steam_3.png',
    '[真的六]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/023c6ec6575c4952ae77c4bd74d2a72f/expressconfig/steam_3.png',
    '[白子说话]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/202eb7ce3c5742c194a95fc0ddd94584/expressconfig/steam_3.png',
    '[黑子说话3]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/24f3300a0a964b7fb87da623893bc753/expressconfig/steam_3.png',
    '[俺不中嘞]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/c0a00ac14515474f8f65101132964e76/expressconfig/steam_3.png',
    '[这瓜保熟吗]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1629978877steam_3.png',
    '[我不理解]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1629978857steam_3.png',
    '[你好有本领啊]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1633760698steam_3.png',
    '[破防了]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1637921177steam_3.png',
    '[摆烂]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1637921193steam_3.png',
    '[赢麻了]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1636083068steam_3.png',
    '[贴贴]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1639125875steam_3.png',
    '[冲鸭]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1639537717steam_3.png',
    '[好家伙]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1628217761steam_3.png',
    '[你礼貌吗]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1628217778steam_3.png',
    '[栓Q]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1652683448steam_3.png',
    '[炫]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1654832600steam_3.png',
    '[可爱滴捏]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1655452661steam_3.png',
    '[全是感情]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1655452979steam_3.png',
    '[已经结束咧]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1656671691steam_3.png',
    '[就是玩儿]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1631872668steam_3.png',
    '[我emo了]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1637313705steam_3.png',
    '[懂的都懂]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1637313653steam_3.png',
    '[你相信光吗]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1633760683steam_3.png',
    '[你是真的gou]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1632897534steam_3.png',
    '[勇敢牛牛不怕困难]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1625140968steam_3.png',
    '[社交牛逼症]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1631267767steam_3.png',
    '[绝绝子]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1632659203steam_3.png',
    '[那我当房外人]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1632659218steam_3.png',
    '[不回我很酷]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1623816934steam_3.png',
    '[丝滑]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1637313692steam_3.png',
    '[躺平1]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1648203074steam_3.png',
    '[摸鱼鱼]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1649412887steam_3.png',
    '[看乐了]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1654832366steam_3.png',
    '[轻轻敲醒]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1656062145steam_3.png',
    '[牛哇]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1649939757steam_3.png',
    '[让我看看梗]': 'http://cdnfile1.msstatic.com/cdnfile/expressconfig/1649939773steam_3.png',
    '[牛波一]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/aee99479b07042a9be457dcd8d6aeb7f/expressconfig/steam_3.png',
    '[别闹了]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/ff7f7665699543719a9b55eb6fcd9a00/expressconfig/steam_3.png',
    '[想咋滴]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/51e3baac4b854147806f635ec0dabfd7/expressconfig/steam_3.png',
    '[贴脸开大]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/21c48719ad4c474c9d246508511adb30/expressconfig/steam_3.png',
    '[还在演]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/90dcd501b90044b99b11e5bf0b522053/expressconfig/steam_3.png',
    '[下饭操作]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/6463ef711e074a24a6bd5c2993b27344/expressconfig/steam_3.png',
    '[真小丑]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/5c285481fd234b03afb8895ae915c1fc/expressconfig/steam_3.png',
    '[那咋啦]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/a7bcac402efe4f61a3052e6649d9d060/expressconfig/steam_3.png',
    '[三连问]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/ddaac95f714147eda8bcc7f77d951d41/expressconfig/steam_3.png',
    '[这事闹的]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/dd012d8af3b74760a2e8086312de1145/expressconfig/steam_3.png',
    '[你好香啊]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/691fce42d2ac486293468bb9a86ef1eb/expressconfig/steam_3.png',
    '[彳亍]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/f50e346e2bb5450b9c29f4bda53b752e/expressconfig/steam_3.png',
    '[闹呢]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/b88ec557b6514de9996dbed01cc06cb8/expressconfig/steam_3.png',
    '[太拉勒]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/62a13e439ec34234a2c1f82da6f3d250/expressconfig/steam_3.png',
    '[理所当然]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/5233b74530d54f94be0ccbe9b6175c6f/expressconfig/steam_3.png',
    '[前方高能]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/5bd5391455b34539950a3a1fbee498e7/expressconfig/steam_3.png',
    '[仍有高手]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/316c94a267964d89bb8382921d508c00/expressconfig/steam_3.png',
    '[难绷1]': 'https://fileserver.cdn.huya.com/web_admin_material_zip_url/599afbc84a5b4105b2b3ed52aadb5b08/expressconfig/steam_3.png',
  };

  /// ★ 全局表情注册表（内置种子，进房即可用）
  static final Map<String, String> emoteRegistry = {};
  static bool _emoteSeeded = false;
  static void _seedBuiltinEmotes() {
    if (_emoteSeeded) return;
    _emoteSeeded = true;
    _builtinEmotes.forEach(
        (k, v) => emoteRegistry.putIfAbsent(k, () => _fixEmoteUrl(v)));
  }

  /// ★ express 的 steam.png 加载不出，统一换 steam_3.png
  static String _fixEmoteUrl(String url) {
    const bad = 'steam.png';
    if (url.endsWith(bad)) {
      return url.substring(0, url.length - bad.length) + 'steam_3.png';
    }
    return url;
  }

  /// ★ 爷牌 guiyepai.png 加载不出，换 guiyepai_3.png
  static String _fixBadgeUrl(String url) {
    if (url.contains('guiyepai') && !url.contains('_3.png')) {
      return url.replaceAll('guiyepai.png', 'guiyepai_3.png');
    }
    return url;
  }

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
  bool _rctOk = false;
  String _traceId = '';

  int _loginUid = 0;
  String _guid = '';
  String _token = '';
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

  String _cookieVal(String name) {
    final m = RegExp('$name=([^;]+)').firstMatch(_cookie);
    return m?.group(1)?.trim() ?? '';
  }

  String _randHex(int n) {
    const chars = '0123456789abcdef';
    return List.generate(n, (_) => chars[Random().nextInt(16)]).join();
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
    _lastType = -1;
    _topSid = topSid;
    _subSid = subSid;
    _ayyuid = uid > 0 ? uid : topSid;
    _roomIdStr = roomIdStr;
    _verified = false;
    _registered = false;
    _rctOk = false;
    _cmdSeq = 0;

    _seedBuiltinEmotes();
    if (emoteRegistry.isNotEmpty) {
      Future.delayed(
          const Duration(milliseconds: 100), () => onEmoteReady?.call());
    }

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
      _send(_wrapWsCmd(
          _withPrefix(
              _wupBody('launch', 'wsTimeSync', {'tReq': _treq(_buildLaunchReq())})),
          3));
    });
    Timer(const Duration(milliseconds: 600), () {
      if (_closed) return;
      _sendRegister();
    });
    Timer(const Duration(milliseconds: 900), () {
      if (_closed) return;
      _sendSubscribeHistory();
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

  // ================= 自适应订阅（动态组包，无硬编码模板） =================
  void _sendSubscribeHistory() {
    _sendSub33(_buildSub33Body('chat:', const [6211]));
    _sendSub33(_buildSub33Body(
        'live:', const [6291, 6479, 6481, 6483, 7107, 7108, 7109, 7114]));
  }

  Uint8List _buildSub33Body(String group, List<int> ids) {
    final val = _TarsWriter();
    val.writeIntIntMap(1, {for (final i in ids) i: 1});
    val.writeInt(3, 1);

    final body = _TarsWriter();
    body.writeString(0, 'HUYA&ZH&2052');
    body.writeString(1, _guid);
    body.writeInt(2, 0);
    body.writeInt(3, 0);
    body.writeStructMap(6, {'$group$_ayyuid': val});
    body.writeInt(7, 0);
    body.writeInt(8, 0);
    body.writeInt(2, 0);
    body.writeString(3, '');
    body.writeInt(4, 0);
    body.writeInt(5, 0);
    body.writeString(6, '');
    return body.toBytes();
  }

  void _sendSub33(Uint8List body) {
    final cmd = _TarsWriter();
    cmd.writeInt(0, 33);
    cmd.writeBytes(1, body);
    cmd.writeInt(2, ++_reqId);
    _send(cmd.toBytes());
    _dbgPush('订阅33 已发');
  }

  // ================= 历史弹幕（tReq 扁平，不二次包裹） =================
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

      if (servant == 'mobileui' && func == 'getRctTimedMessage') {
        int n = 0;
        int listLen = -1;
        void collect(dynamic node, int depth) {
          if (depth > 14 || n > 60) return;
          if (node is Map<int, Object?>) {
            Map<int, Object?>? msgNode;
            if (node[3] is String && node[0] is Map<int, Object?>) {
              msgNode = node;
            } else if (node[0] is Map<int, Object?> &&
                (node[0] as Map<int, Object?>)[3] is String) {
              msgNode = node[0] as Map<int, Object?>;
            }
            if (msgNode != null && _emitFromFields(msgNode, history: true)) {
              n++;
              return;
            }
            final nk = node[5];
            final ct = node[6];
            if (nk is String &&
                ct is String &&
                nk.isNotEmpty &&
                ct.isNotEmpty &&
                ct != nk) {
              _controller.add(DanmakuMessage(
                  nickname: nk, content: ct, isHistory: true));
              n++;
              return;
            }
            node.values.forEach((v) => collect(v, depth + 1));
          } else if (node is List) {
            if (node.isNotEmpty && node.first is int) {
              try {
                final parsed = _TarsReader(Uint8List.fromList(node.cast<int>()))
                    .readFields();
                if (parsed.isNotEmpty) collect(parsed, depth + 1);
              } catch (_) {}
              return;
            }
            if (listLen < 0 &&
                node.isNotEmpty &&
                node.first is Map<int, Object?>) {
              listLen = node.length;
            }
            node.forEach((v) => collect(v, depth + 1));
          }
        }

        final sb = f[7];
        if (sb is List) collect(sb, 0);
        if (n > 0) _rctOk = true;
        _dbgPush('历史弹幕 $n 条(list=$listLen)');
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
    final sender = senderRaw;
    dynamic uidVal = sender[0];
    if (uidVal is Map<int, Object?>) uidVal = uidVal[0];
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
        if (cf[0] is int &&
            (cf[0] as int) >= 0x10000 &&
            (cf[0] as int) <= 0xFFFFFF) {
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
      if (fansName.isNotEmpty || depth > 8) return;
      if (node is Map<int, Object?>) {
        if (isName(node[3]) &&
            node[4] is int &&
            node[4] as int >= 1 &&
            node[4] as int <= 99) {
          fansName = node[3] as String;
          fansLevel = node[4] as int;
          return;
        }
        if (isName(node[2]) &&
            node[3] is int &&
            node[3] as int >= 1 &&
            node[3] as int <= 99 &&
            node[0] is int) {
          fansName = node[2] as String;
          fansLevel = node[3] as int;
          return;
        }
        node.values.forEach((v) => findFans(v, depth + 1));
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            final inner =
                _TarsReader(Uint8List.fromList(node.cast<int>())).readFields();
            if (inner.isNotEmpty) findFans(inner, depth + 1);
          } catch (_) {}
        } else {
          node.forEach((v) => findFans(v, depth + 1));
        }
      }
    }

    findFans(msg, 0);

    // 收集徽章：爷牌(归一化_3) → 粉钻/粉丝钻 → 房管，顺序与网页一致
    final found = <String>[];
    void findBadges(dynamic node, int depth) {
      if (depth > 8) return;
      if (node is Map<int, Object?>) {
        node.values.forEach((v) => findBadges(v, depth + 1));
      } else if (node is List) {
        if (node.isNotEmpty && node.first is int) {
          try {
            findBadges(
                _TarsReader(Uint8List.fromList(node.cast<int>())).readFields(),
                depth + 1);
          } catch (_) {}
        } else {
          node.forEach((v) => findBadges(v, depth + 1));
        }
      } else if (node is String && node.startsWith('http')) {
        if (node.contains('guiyepai') ||
            node.contains('PendantInfoZip') ||
            node.contains('fenzuan') ||
            node.contains('fengzuan') ||
            node.contains('fangguan')) {
          if (!found.contains(node)) found.add(node);
        }
      }
    }

    findBadges(msg, 0);
    final badges = <String>[];
    for (final u in found) {
      if (u.contains('guiyepai')) badges.add(_fixBadgeUrl(u));
    }
    for (final u in found) {
      if (u.contains('PendantInfoZip') ||
          u.contains('fenzuan') ||
          u.contains('fengzuan')) badges.add(u);
    }
    for (final u in found) {
      if (u.contains('fangguan')) badges.add(u);
    }

    _controller.add(DanmakuMessage(
      nickname: nick,
      content: content,
      fontColor: color <= 0 ? 0xFFFFFFFF : (color | 0xFF000000),
      avatar: avatar,
      uid: uidVal,
      fansName: fansName,
      fansLevel: fansLevel,
      managerType: managerType,
      badgeUrls: badges,
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
        if (v is String && v.startsWith('http')) {
          avatar = v;
          break;
        }
      }
      _controller.add(DanmakuMessage(
        nickname: nick,
        content: content,
        avatar: avatar,
        isHistory: true,
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

  /// int→int map（订阅 id 用）
  void writeIntIntMap(int tag, Map<int, int> m) {
    _head(tag, 8);
    _intValue(m.length);
    m.forEach((k, v) {
      writeInt(0, k);
      writeInt(1, v);
    });
  }

  /// string→struct map（订阅分组用）
  void writeStructMap(int tag, Map<String, _TarsWriter> m) {
    _head(tag, 8);
    _intValue(m.length);
    m.forEach((k, v) {
      writeString(0, k);
      _head(1, 10);
      _b.add(v._b.toBytes());
      _b.addByte(0x0B);
    });
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
