import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crypto/crypto.dart';
import '../model/danmaku_message.dart';
import 'tars/tars_reader.dart';
import 'tars/tars_writer.dart';

class HuyaDanmakuClient {
  WebSocketChannel? _channel;
  StreamController<DanmakuMessage>? _controller;
  Timer? _heartbeatTimer;
  bool _connected = false;

  Stream<DanmakuMessage>? get danmakuStream => _controller?.stream;
  bool get isConnected => _connected;

  /// 连接虎牙弹幕服务器
  Future<void> connect({
    required int uid,
    required String roomId,
    required int presenterUid,
    String cookie = '',
  }) async {
    _controller = StreamController<DanmakuMessage>.broadcast();

    // 虎牙 WebSocket 地址
    final wsUrl = 'wss://cdnws.api.huya.com';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await _channel!.ready;
    _connected = true;

    // 发送注册包
    final registerPayload = _buildRegisterPayload(uid, roomId, presenterUid);
    _channel!.sink.add(registerPayload);

    // 启动心跳
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
      },
      onError: (e) {
        _connected = false;
        _heartbeatTimer?.cancel();
      },
    );
  }

  /// 构造注册包 (WSRegisterGroupReq)
  Uint8List _buildRegisterPayload(int uid, String roomId, int presenterUid) {
    // 构造 RegisterGroup 内部结构
    final innerWriter = TarsWriter();
    // vGroupId: ["live:{presenterUid}", "chat:{presenterUid}"]
    innerWriter.writeTag(0, 9); // LIST
    innerWriter.writeInt32(0, 2); // size = 2
    innerWriter.writeString(0, 'live:$presenterUid');
    innerWriter.writeString(0, 'chat:$presenterUid');

    // 外层 WebSocketCommand
    final outerWriter = TarsWriter();
    outerWriter.writeInt32(0, 1); // iCmdType = EWSCmdC2S_RegisterGroupReq
    outerWriter.writeBytes(1, innerWriter.bytes); // vData
    outerWriter.writeInt64(2, DateTime.now().millisecondsSinceEpoch); // lRequestId

    return outerWriter.bytes;
  }

  /// 发送心跳
  void _sendHeartbeat() {
    if (!_connected) return;
    final writer = TarsWriter();
    writer.writeInt32(0, 3); // iCmdType = EWSCmdC2S_HeartBeatReq
    writer.writeInt64(2, DateTime.now().millisecondsSinceEpoch);
    _channel?.sink.add(writer.bytes);
  }

  /// 处理收到的消息
  void _handleMessage(Uint8List data) {
    try {
      final reader = TarsReader(data);
      final cmdType = reader.readInt(0);

      // EWSCmdS2C_MsgPushReq = 4
      if (cmdType == 4) {
        final payload = reader.readBytes(1);
        if (payload.isNotEmpty) {
          _parsePushMessage(payload);
        }
      }
    } catch (e) {
      // 解析失败，忽略
    }
  }

  /// 解析推送消息
  void _parsePushMessage(Uint8List data) {
    try {
      final reader = TarsReader(data);
      final uri = reader.readInt(1);

      // 弹幕消息 uri = 1400 (MessageNotice)
      if (uri == 1400) {
        final msgData = reader.readBytes(2);
        final msg = _parseMessageNotice(msgData);
        if (msg != null) {
          _controller?.add(msg);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  /// 解析 MessageNotice 弹幕结构
  DanmakuMessage? _parseMessageNotice(Uint8List data) {
    try {
      final reader = TarsReader(data);
      // MessageNotice 结构:
      // tag 0: tUserInfo (UserId)
      // tag 1: lTid
      // tag 2: lSid
      // tag 3: lPid
      // tag 4: sContent (弹幕内容)
      // tag 5: iShowMode
      // tag 6: tFormat
      // tag 7: iBulletFormat
      // ...
      final content = reader.readString(4);
      if (content.isEmpty) return null;

      // 解析 tUserInfo (tag 0) 获取昵称
      final savedPos = reader.pos;
      String nickname = '';
      int uid = 0;
      if (reader.skipToTag(0)) {
        // 进入 struct
        final (_, type) = reader.readTagType();
        if (type == 10) { // STRUCT_BEGIN
          // UserId: tag 0 = lUid, tag 3 = sNick
          uid = reader.readInt(0);
          nickname = reader.readString(3);
          // 跳过到 STRUCT_END
          while (reader.hasRemaining) {
            var (_, t) = reader.readTagType();
            if (t == 11) break;
            reader._skipTypeInternal(t);
          }
        }
      }
      reader.pos = savedPos;

      return DanmakuMessage(
        nickname: nickname.isNotEmpty ? nickname : '用户$uid',
        content: content,
        uid: uid,
      );
    } catch (e) {
      return null;
    }
  }

  /// 断开连接
  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    _controller?.close();
  }
}
