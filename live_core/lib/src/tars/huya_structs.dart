import 'dart:typed_data';
import 'tars_reader.dart';
import 'tars_writer.dart';

/// 虎牙 UserId 结构
/// 来源: taf-signal.global.0.1.2.prod.js
class HuyaUserId {
  int lUid = 0;
  String sGuid = '';
  String sToken = '';
  String sHuYaUA = '';
  String sCookie = '';
  int iTokenType = 0;

  void writeTo(TarsWriter writer) {
    writer.writeInt64(0, lUid);
    writer.writeString(1, sGuid);
    writer.writeString(2, sToken);
    writer.writeString(3, sHuYaUA);
    writer.writeString(4, sCookie);
    writer.writeInt32(5, iTokenType);
  }

  static HuyaUserId readFrom(TarsReader reader) {
    var userId = HuyaUserId();
    userId.lUid = reader.readInt(0);
    userId.sGuid = reader.readString(1);
    userId.sToken = reader.readString(2);
    userId.sHuYaUA = reader.readString(3);
    userId.sCookie = reader.readString(4);
    userId.iTokenType = reader.readInt(5);
    return userId;
  }
}

/// 弹幕消息 (MessageNotice)
class HuyaMessageNotice {
  HuyaUserId userInfo = HuyaUserId();
  int lTid = 0;
  int lSid = 0;
  int lPid = 0;
  String sContent = '';
  int iShowMode = 0;
  int iBulletFormat = 0;
  int iFontColor = -1;
  int iFontSize = 4;
  int iAnonymous = 0;
  int iMode = 0;

  static HuyaMessageNotice readFrom(TarsReader reader) {
    var msg = HuyaMessageNotice();
    // tag 0: tUserInfo (struct)
    var hd = reader.skipToTag(0);
    if (hd != null && hd.type == 10) {
      msg.userInfo = HuyaUserId.readFrom(reader);
      reader.skipStruct();
    }
    msg.lTid = reader.readInt(1);
    msg.lSid = reader.readInt(2);
    msg.lPid = reader.readInt(3);
    msg.sContent = reader.readString(4);
    msg.iShowMode = reader.readInt(5);
    msg.iBulletFormat = reader.readInt(6);
    msg.iFontColor = reader.readInt(7, defaultValue: -1);
    msg.iFontSize = reader.readInt(8, defaultValue: 4);
    msg.iAnonymous = reader.readInt(9);
    msg.iMode = reader.readInt(10);
    return msg;
  }
}

/// WebSocket 推送消息 (WSPushMessage)
class HuyaWSPushMessage {
  int ePushType = 0;
  int iUri = 0;
  Uint8List sMsg = Uint8List(0);
  int iProtocolType = 0;
  String sGroupId = '';
  int lMsgId = 0;
  int iMsgTag = 0;

  static HuyaWSPushMessage readFrom(TarsReader reader) {
    var msg = HuyaWSPushMessage();
    msg.ePushType = reader.readInt(0);
    msg.iUri = reader.readInt(1);
    msg.sMsg = reader.readBytes(2);
    msg.iProtocolType = reader.readInt(3);
    msg.sGroupId = reader.readString(4);
    msg.lMsgId = reader.readInt(5);
    msg.iMsgTag = reader.readInt(6);
    return msg;
  }
}

/// WebSocket 命令 (WebSocketCommand)
class HuyaWebSocketCommand {
  int iCmdType = 0;
  Uint8List vData = Uint8List(0);
  int lRequestId = 0;
  String traceId = '';
  int iEncryptType = 0;
  int lTime = 0;
  String sMD5 = '';

  void writeTo(TarsWriter writer) {
    writer.writeInt32(0, iCmdType);
    writer.writeBytes(1, vData);
    writer.writeInt64(2, lRequestId);
    writer.writeString(3, traceId);
    writer.writeInt32(4, iEncryptType);
    writer.writeInt64(5, lTime);
    writer.writeString(6, sMD5);
  }

  static HuyaWebSocketCommand readFrom(TarsReader reader) {
    var cmd = HuyaWebSocketCommand();
    cmd.iCmdType = reader.readInt(0);
    cmd.vData = reader.readBytes(1);
    cmd.lRequestId = reader.readInt(2);
    cmd.traceId = reader.readString(3);
    cmd.iEncryptType = reader.readInt(4);
    cmd.lTime = reader.readInt(5);
    cmd.sMD5 = reader.readString(6);
    return cmd;
  }
}

/// 注册分组请求 (WSRegisterGroupReq)
class HuyaRegisterGroupReq {
  List<String> vGroupId = [];
  String sToken = '';

  void writeTo(TarsWriter writer) {
    writer.writeListBegin(0, vGroupId.length);
    for (var id in vGroupId) {
      writer.writeString(0, id);
    }
    writer.writeString(1, sToken);
  }
}

/// 粉丝数请求 (FansNumReq)
/// 来源: taf-signal.global.0.1.2.prod.js
class HuyaFansNumReq {
  HuyaUserId tUserId = HuyaUserId();
  int lPid = 0;

  void writeTo(TarsWriter writer) {
    writer.writeStructBegin(0);
    tUserId.writeTo(writer);
    writer.writeStructEnd();
    writer.writeInt64(1, lPid);
  }
}

/// 订阅/关注请求 (ModRelationReq)
/// 来源: taf-signal.global.0.1.2.prod.js
class HuyaModRelationReq {
  HuyaUserId tId = HuyaUserId();
  int lUid = 0;
  int iOp = 0; // 1=关注, 2=取消关注
  String sSource = '';

  void writeTo(TarsWriter writer) {
    writer.writeStructBegin(0);
    tId.writeTo(writer);
    writer.writeStructEnd();
    writer.writeInt64(1, lUid);
    writer.writeInt32(2, iOp);
    writer.writeString(3, sSource);
  }
}

/// EWSCmd 命令类型枚举
class EWSCmdType {
  static const int C2S_RegisterGroupReq = 1;
  static const int C2S_UnRegisterGroupReq = 2;
  static const int C2S_HeartBeatReq = 3;
  static const int C2S_WupReq = 4;
  static const int S2C_MsgPushReq = 5;
  static const int C2S_UpdateUserInfoReq = 6;
}

/// 弹幕消息 URI
class HuyaMsgUri {
  static const int MessageNotice = 1400; // 弹幕
  static const int MessageNotice2 = 1401; // 弹幕（备用）
  static const int GiftNotice = 1402; // 礼物
  static const int EnterNotice = 1403; // 进场
  static const int GuardNotice = 1404; // 守护
}
