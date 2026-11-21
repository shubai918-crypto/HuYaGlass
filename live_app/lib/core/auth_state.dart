import 'package:get/get.dart';
import 'package:live_core/live_core.dart';

/// 登录态单一响应式数据源：保存/退出立即刷新，全 App Obx 监听
class AuthState extends GetxService {
  static AuthState get to => Get.find();

  final loggedIn = false.obs;
  final cookie = ''.obs;

  /// App 启动时同步一次真实状态
  void refresh() {
    loggedIn.value = HuyaLoginManager().isLoggedIn;
  }

  /// 保存 cookie：成功立即置 loggedIn=true（无需重启）
  Future<bool> save(String rawCookie) async {
    final m = HuyaLoginManager();
    // ★ 若 live_core 中持久化方法名不是 saveCookie（如 setCookie/login），只改这一行
    final ok = await m.saveCookie(rawCookie);
    if (ok) {
      loggedIn.value = true;
      cookie.value = rawCookie;
    }
    return ok;
  }

  /// 退出：立即置 false，全 App 即时回到未登录
  Future<void> logout() async {
    await HuyaLoginManager().logout();
    loggedIn.value = false;
    cookie.value = '';
  }
}
