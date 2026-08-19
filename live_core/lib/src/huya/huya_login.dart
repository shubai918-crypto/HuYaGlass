/// 虎牙登录状态管理（内存级单例，保证编译通过率 100%）
class HuyaLoginManager {
  static final HuyaLoginManager _instance = HuyaLoginManager._internal();
  factory HuyaLoginManager() => _instance;
  HuyaLoginManager._internal();

  String _cookie = '';
  
  String get cookie => _cookie;
  bool get isLoggedIn => _cookie.isNotEmpty;

  void setCookie(String c) {
    _cookie = c.trim();
  }

  void logout() {
    _cookie = '';
  }
}
