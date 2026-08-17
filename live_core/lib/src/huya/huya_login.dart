import 'dart:convert';

/// 虎牙登录态管理
class HuyaLoginManager {
  String _cookie = '';
  int _uid = 0;
  String _guid = '';
  String _token = '';

  String get cookie => _cookie;
  int get uid => _uid;
  String get guid => _guid;
  String get token => _token;
  bool get isLoggedIn => _uid > 0 && _cookie.isNotEmpty;

  /// 从 WebView Cookie 字符串中解析登录态
  void parseCookie(String cookieStr) {
    _cookie = cookieStr;
    // 解析 udb_uid
    var uidMatch = RegExp(r'udb_uid=(\d+)').firstMatch(cookieStr);
    if (uidMatch != null) {
      _uid = int.tryParse(uidMatch.group(1)!) ?? 0;
    }
    // 解析 udb_guid
    var guidMatch = RegExp(r'udb_guid=([a-zA-Z0-9]+)').firstMatch(cookieStr);
    if (guidMatch != null) {
      _guid = guidMatch.group(1)!;
    }
    // 解析 yep_token (sToken)
    var tokenMatch = RegExp(r'yep_token=([a-zA-Z0-9]+)').firstMatch(cookieStr);
    if (tokenMatch != null) {
      _token = tokenMatch.group(1)!;
    }
  }

  /// 序列化登录态
  Map<String, dynamic> toJson() => {
    'cookie': _cookie,
    'uid': _uid,
    'guid': _guid,
    'token': _token,
  };

  /// 反序列化登录态
  void fromJson(Map<String, dynamic> json) {
    _cookie = json['cookie'] ?? '';
    _uid = json['uid'] ?? 0;
    _guid = json['guid'] ?? '';
    _token = json['token'] ?? '';
  }

  void logout() {
    _cookie = '';
    _uid = 0;
    _guid = '';
    _token = '';
  }
}
