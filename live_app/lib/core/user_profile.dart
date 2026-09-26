import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 独立用户资料服务（零侵入 live_core）：
/// UID 取自登录 Cookie 的 yyuid；头像/昵称/等级/签名
/// 取自虎牙个人中心 https://i.huya.com/ 的明文 HTML 锚点。
class UserProfile extends GetxService {
  static UserProfile get to => Get.find<UserProfile>();

  final logged = false.obs;
  final nickname = ''.obs;
  final avatar = ''.obs;
  final uid = ''.obs;
  final level = ''.obs;
  final signature = ''.obs;

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

  String _cookieVal(String name) {
    final m = RegExp('$name=([^;]+)').firstMatch(_cookie);
    return m?.group(1)?.trim() ?? '';
  }

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (nickname.isEmpty) nickname.value = prefs.getString('huya_nick') ?? '';
      if (avatar.isEmpty) avatar.value = prefs.getString('huya_avatar') ?? '';
      if (uid.isEmpty) uid.value = prefs.getString('huya_uid') ?? '';
      if (level.isEmpty) level.value = prefs.getString('huya_level') ?? '';
      if (signature.isEmpty) signature.value = prefs.getString('huya_sign') ?? '';
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('huya_nick', nickname.value);
      await prefs.setString('huya_avatar', avatar.value);
      await prefs.setString('huya_uid', uid.value);
      await prefs.setString('huya_level', level.value);
      await prefs.setString('huya_sign', signature.value);
    } catch (_) {}
  }

  Future<void> refresh() async {
    logged.value = _isLoggedIn();
    if (!logged.value || _fetching) return;
    _fetching = true;
    try {
      // UID：Cookie 直解
      final yyuid = _cookieVal('yyuid').isNotEmpty
          ? _cookieVal('yyuid')
          : _cookieVal('udb_uid');
      if (yyuid.isNotEmpty) uid.value = yyuid;
      // 头像/昵称/等级/签名：个人中心 HTML
      await _fetchFromICenter();
      await _saveCache();
    } catch (e) {
      debugPrint('UserProfile.refresh 失败: $e');
    } finally {
      _fetching = false;
      logged.value = _isLoggedIn();
    }
  }

  /// ★ 带 Cookie 请求个人中心，按明文锚点精确解析
  Future<void> _fetchFromICenter() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('https://i.huya.com/'))
          .timeout(const Duration(seconds: 8));
      req.headers.set('Cookie', _cookie);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
      req.headers.set('Referer', 'https://i.huya.com/');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body =
          await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
      client.close(force: true);

      // 头像: <img class="user_icon" src="..." alt="头像">
      final am = RegExp(r'class="user_icon"[^>]*?src="([^"]+)"').firstMatch(body);
      if (am != null) {
        var av = _decodeEntities(am.group(1)!).trim();
        if (av.startsWith('//')) av = 'https:$av';
        if (av.startsWith('http')) avatar.value = av;
      }
      // 昵称: <h2 class="uesr_n">sandcarving</h2>
      final nm = RegExp(r'<h2\s+class="uesr_n">([^<]+)</h2>').firstMatch(body);
      if (nm != null) {
        final n = _decodeEntities(nm.group(1)!).trim();
        if (n.isNotEmpty) nickname.value = n;
      }
      // 等级: <span class="c-lv">LV1</span>
      final lm = RegExp(r'<span\s+class="c-lv">([^<]+)</span>').firstMatch(body);
      if (lm != null) level.value = lm.group(1)!.trim();
      // 签名: 个性签名: <span>...</span>（默认未编辑则置空）
      final sm = RegExp(r'个性签名:\s*<span>([^<]*)</span>').firstMatch(body);
      if (sm != null) {
        final s = _decodeEntities(sm.group(1)!).trim();
        signature.value = (s.isEmpty || s.contains('你还没编辑')) ? '' : s;
      }
    } catch (e) {
      debugPrint('UserProfile._fetchFromICenter 失败: $e');
    }
  }

  Future<void> clear() async {
    logged.value = false;
    nickname.value = '';
    avatar.value = '';
    uid.value = '';
    level.value = '';
    signature.value = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('huya_nick');
      await prefs.remove('huya_avatar');
      await prefs.remove('huya_uid');
      await prefs.remove('huya_level');
      await prefs.remove('huya_sign');
    } catch (_) {}
  }
}
