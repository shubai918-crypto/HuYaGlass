import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录态单一响应式数据源
class AuthState extends GetxService {
  static AuthState get to => Get.find();

  final loggedIn = false.obs;
  final cookie = ''.obs;

  // ★ 与 HuyaLoginManager 持久化所用 key 保持一致（若不同改这一行）
  static const String _kCookieKey = 'huya_cookie';

  void refresh() {
    loggedIn.value = HuyaLoginManager().isLoggedIn;
  }

  /// 保存 cookie：写 prefs → 重载 manager → 立即置 loggedIn（无需重启）
  Future<bool> save(String rawCookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCookieKey, rawCookie);
    await HuyaLoginManager.init();
    final ok = HuyaLoginManager().isLoggedIn;
    if (ok) {
      loggedIn.value = true;
      cookie.value = rawCookie;
    }
    return ok;
  }

  /// 退出：manager.logout 是 void，同步调用；包装成 Future 便于外部 await
  Future<void> logout() async {
    HuyaLoginManager().logout();
    loggedIn.value = false;
    cookie.value = '';
  }
}
