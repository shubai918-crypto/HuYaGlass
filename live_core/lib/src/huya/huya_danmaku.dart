import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../model/danmaku_message.dart';
import '../tars/tars_reader.dart';
import '../tars/tars_writer.dart';
import '../tars/huya_structs.dart';
import 'huya_login.dart';

/// 虎牙弹幕 WebSocket 客户端
/// 参考: dtv_mobile HuyaDanmakuClient / vplayerUI.js WebSocketCommand
class HuyaDanmakuClient {
  WebSocketChannel? _channel;
  StreamController<DanmakuMessage>? _controller;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _connected = false;
  bool _shouldReconnect = true;

  final HuyaLoginManager _loginManager;

  int _roomId = 0;
  int _presenterUid = 0;

  Stream<DanmakuMessage>? get danmakuStream => _controller?.stream;
  bool get isConnected => _connected;

  HuyaDanmakuClient(this._loginManager);

  /// 连接弹幕服务器
  Future<void> connect({
    required String roomId,
    required int presenterUid,
  }) async {
    _roomId = int.tryParse(roomId) ?? 0;
    _presenterUid = presenterUid;
    _shouldReconnect = true;

    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      _controller ??= StreamController<DanmakuMessage>.broadcast();

      // 虎牙 WebSocket 弹幕地址
      final wsUrl = 'wss://cdnws.api.huya.com';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      _connected = true;

      // 发送注册包（订阅 live: 和 chat: 分组）
      final registerPayload = _buildRegisterPayload();
      _channel!.sink.add(registerPayload);

      // 启动心跳（每 20 秒）
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _sendHeartbeat();
      });

      // 监听消息
      _channel!.stream.listen(
        (data) {
          if (data is List<int>) {
            _handleMessage(Uint8List.fromList(data));
          }
        },
        onDone: () {
          _connected = false;
          _heartbeatTimer?.cancel();
          _scheduleReconnect();
        },
        onError: (e) {
          _connected = false;
          _heartbeatTimer?.cancel();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect) {
        _doConnect();
      }
    });
  }

  /// 构造注册包 (WSRegisterGroupReq)
  /// 注册 live:{presenterUid} 和 chat:{presenterUid} 分组
  Uint8List _buildRegisterPayload() {
    final innerWriter = TarsWriter();
    // vGroupId: ["live:{uid}", "chat:{uid}"]
    innerWriter.writeTag(0, 9); // LIST
    innerWriter.writeInt32(0, 2); // size
    innerWriter.writeString(0, 'live:$_presenterUid');
    innerWriter.writeString(0, 'chat:$_presenterUid');

    final outerWriter = TarsWriter();
    final cmd = HuyaWebSocketCommand();
    cmd.iCmdType = EWSCmdType.C2S_RegisterGroupReq;
    cmd.vData = innerWriter.bytes;
    cmd.lRequestId = DateTime.now().millisecondsSinceEpoch;
    cmd.writeTo(outerWriter);

    return outerWriter.bytes;
  }

  /// 发送心跳
  void _sendHeartbeat() {
    if (!_connected) return;
    final writer = TarsWriter();
    final cmd = HuyaWebSocketCommand();
    cmd.iCmdType = EWSCmdType.C2S_HeartBeatReq;
    cmd.lRequestId = DateTime.now().millisecondsSinceEpoch;
    cmd.writeTo(writer);
    _channel?.sink.add(writer.bytes);
  }

  /// 处理收到的 WebSocket 消息
  void _handleMessage(Uint8List data) {
    try {
      final reader = TarsReader(data);
      final cmd = HuyaWebSocketCommand.readFrom(reader);

      // S2C_MsgPushReq = 5 (服务器推送消息)
      if (cmd.iCmdType == EWSCmdType.S2C_MsgPushReq) {
        _parsePushMessage(cmd.vData);
      }
    } catch (e) {
      // 解析失败，忽略
    }
  }

  /// 解析推送消息
  void _parsePushMessage(Uint8List data) {
    try {
      final reader = TarsReader(data);
      final pushMsg = HuyaWSPushMessage.readFrom(reader);

      // 弹幕消息 uri = 1400 (MessageNotice)
      if (pushMsg.iUri == HuyaMsgUri.MessageNotice ||
          pushMsg.iUri == HuyaMsgUri.MessageNotice2) {
        _parseMessageNotice(pushMsg.sMsg);
      }
    } catch (e) {
      // ignore
    }
  }

  /// 解析 MessageNotice 弹幕结构
  void _parseMessageNotice(Uint8List data) {
    try {
      final reader = TarsReader(data);
      final notice = HuyaMessageNotice.readFrom(reader);

      if (notice.sContent.isEmpty) return;

      final danmaku = DanmakuMessage(
        nickname: notice.userInfo.lUid > 0
            ? '用户${notice.userInfo.lUid}'
            : '匿名',
        content: notice.sContent,
        uid: notice.userInfo.lUid,
        fontColor: notice.iFontColor,
        fontSize: notice.iFontSize,
      );

      _controller?.add(danmaku);
    } catch (e) {
      // ignore
    }
  }

  /// 发送弹幕（需要登录态）
  /// 参考: vplayerUI.js sendWup2("chatui", "sendMessage", ...)
  Future<bool> sendDanmaku(String content) async {
    if (!_connected) return false;
    if (!_loginManager.isLoggedIn) return false;

    try {
      // 构造 SendMessageReq
      final reqWriter = TarsWriter();

      // tag 0: tId (UserId)
      reqWriter.writeStructBegin(0);
      final userId = HuyaUserId();
      userId.lUid = _loginManager.uid;
      userId.sGuid = _loginManager.guid;
      userId.sToken = _loginManager.token;
      userId.sCookie = _loginManager.cookie;
      userId.writeTo(reqWriter);
      reqWriter.writeStructEnd();

      // tag 1: lPid (主播 UID)
      reqWriter.writeInt64(1, _presenterUid);
      // tag 2: sContent (弹幕内容)
      reqWriter.writeString(2, content);
      // tag 3: iType
      reqWriter.writeInt32(3, 0);

      final reqBytes = reqWriter.bytes;

      // 构造 WUP 包装
      final wupWriter = TarsWriter();
      wupWriter.writeInt16(1, 3); // version
      wupWriter.writeInt8(2, 0); // packetType
      wupWriter.writeInt32(3, 0); // messageType
      wupWriter.writeInt32(4, DateTime.now().millisecondsSinceEpoch ~/ 1000);
      wupWriter.writeString(5, 'chatui'); // servant
      wupWriter.writeString(6, 'sendMessage'); // funcName
      wupWriter.writeBytes(7, reqBytes); // buffer
      wupWriter.writeInt32(8, 5000); // timeout

      final wupBytes = wupWriter.bytes;

      // 构造 WebSocketCommand
      final cmdWriter = TarsWriter();
      final cmd = HuyaWebSocketCommand();
      cmd.iCmdType = EWSCmdType.C2S_WupReq;
      cmd.vData = wupBytes;
      cmd.lRequestId = DateTime.now().millisecondsSinceEpoch;
      cmd.writeTo(cmdWriter);

      _channel?.sink.add(cmdWriter.bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 断开连接
  void disconnect() {
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    _controller?.close();
    _controller = null;
  }
}
