import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 独立用户资料服务（零侵入 live_core）：
/// 带 Cookie 请求虎牙首页，解析 TT_PROFILE_INFO 获取真实头像/昵称/UID，并本地持久化。
class UserProfile extends GetxService {
  static UserProfile get to => Get.find<UserProfile>();

  final logged = false.obs;
  final nickname = ''.obs;
  final avatar = ''.obs;
  final uid = ''.obs;

  bool _fetching = false;

  @override
  void onInit() {
    super.onInit();
    logged.value = _isLoggedIn();
    _loadCache();
    if (logged.value) refresh();
  }

  bool _isLoggedIn() {
    try {
      return HuyaLoginManager().isLoggedIn;
    } catch (_) {
      return false;
    }
  }

  String get _cookie {
    try {
      return HuyaLoginManager().cookie;
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      nickname.value = prefs.getString('huya_nick') ?? '';
      avatar.value = prefs.getString('huya_avatar') ?? '';
      uid.value = prefs.getString('huya_uid') ?? '';
    } catch (_) {}
  }

  /// 拉取真实用户资料（登录态下调用）
  Future<void> refresh() async {
    if (_fetching) return;
    logged.value = _isLoggedIn();
    if (!logged.value) return;
    _fetching = true;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('https://www.huya.com/'))
          .timeout(const Duration(seconds: 8));
      req.headers.set('Cookie', _cookie);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
      req.headers.set('Referer', 'https://www.huya.com/');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body =
          await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
      client.close(force: true);

      final m =
          RegExp(r'var\s+TT_PROFILE_INFO\s*=\s*(\{.*?\});').firstMatch(body);
      if (m != null) {
        final data = jsonDecode(m.group(1)!) as Map<String, dynamic>;
        final nick = (data['nick'] ?? '').toString();
        final av = (data['avatar'] ?? '').toString();
        final u = (data['uid'] ?? '').toString();
        if (nick.isNotEmpty) nickname.value = nick;
        if (av.isNotEmpty) avatar.value = av;
        if (u.isNotEmpty) uid.value = u;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('huya_nick', nickname.value);
        await prefs.setString('huya_avatar', avatar.value);
        await prefs.setString('huya_uid', uid.value);
      }
    } catch (e) {
      debugPrint('UserProfile.refresh 失败: $e');
    } finally {
      _fetching = false;
      logged.value = _isLoggedIn();
    }
  }

  /// 退出登录时清空
  Future<void> clear() async {
    logged.value = false;
    nickname.value = '';
    avatar.value = '';
    uid.value = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('huya_nick');
      await prefs.remove('huya_avatar');
      await prefs.remove('huya_uid');
    } catch (_) {}
  }
}
