import 'dart:convert';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 虎牙登录态管理
class LoginService extends GetxService {
  final _box = Hive.box('settings');

  final isLoggedIn = false.obs;
  final uid = 0.obs;
  final guid = ''.obs;
  final cookie = ''.obs;
  final nickname = ''.obs;
  final avatar = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLogin();
  }

  void _loadSavedLogin() {
    final savedCookie = _box.get('huya_cookie', defaultValue: '') as String;
    if (savedCookie.isNotEmpty) {
      cookie.value = savedCookie;
      uid.value = _box.get('huya_uid', defaultValue: 0) as int;
      guid.value = _box.get('huya_guid', defaultValue: '') as String;
      nickname.value = _box.get('huya_nickname', defaultValue: '') as String;
      avatar.value = _box.get('huya_avatar', defaultValue: '') as String;
      isLoggedIn.value = uid.value > 0;
    }
  }

  /// 从 WebView Cookie 字符串解析登录态
  void parseCookie(String cookieStr) {
    cookie.value = cookieStr;

    // 解析 udb_uid
    final uidMatch = RegExp(r'udb_uid=(\d+)').firstMatch(cookieStr);
    if (uidMatch != null) {
      uid.value = int.tryParse(uidMatch.group(1)!) ?? 0;
    }

    // 解析 udb_guid
    final guidMatch = RegExp(r'udb_guid=([a-zA-Z0-9]+)').firstMatch(cookieStr);
    if (guidMatch != null) {
      guid.value = guidMatch.group(1)!;
    }

    // 保存
    if (uid.value > 0) {
      isLoggedIn.value = true;
      _box.put('huya_cookie', cookieStr);
      _box.put('huya_uid', uid.value);
      _box.put('huya_guid', guid.value);
      Get.snackbar('登录成功', '欢迎回来', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 设置用户信息（从 API 获取）
  void setUserInfo({
    required String nick,
    required String avatarUrl,
  }) {
    nickname.value = nick;
    avatar.value = avatarUrl;
    _box.put('huya_nickname', nick);
    _box.put('huya_avatar', avatarUrl);
  }

  /// 登出
  void logout() {
    isLoggedIn.value = false;
    uid.value = 0;
    guid.value = '';
    cookie.value = '';
    nickname.value = '';
    avatar.value = '';
    _box.delete('huya_cookie');
    _box.delete('huya_uid');
    _box.delete('huya_guid');
    _box.delete('huya_nickname');
    _box.delete('huya_avatar');
    Get.snackbar('已登出', '', snackPosition: SnackPosition.BOTTOM);
  }
}
