import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_app/core/auth_state.dart';
import '../home/home_page.dart';

class HuyaLoginPage extends StatefulWidget {
  const HuyaLoginPage({super.key});
  @override
  State<HuyaLoginPage> createState() => _HuyaLoginPageState();
}

class _HuyaLoginPageState extends State<HuyaLoginPage> {
  final TextEditingController _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      Get.snackbar('提示', '请先粘贴 Cookie', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _saving = true);
    final ok = await AuthState.to.save(raw);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('登录成功', 'Cookie 已保存，登录态即时生效',
          snackPosition: SnackPosition.BOTTOM);
      Get.back(); // ★ 保存成功即返回，首页 Obx 立即变"已登录"
    } else {
      Get.snackbar('登录失败', 'Cookie 无效或保存失败，请检查后重试',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _logout() async {
    await AuthState.to.logout();
    Get.snackbar('已退出', '登录态已清除', snackPosition: SnackPosition.BOTTOM);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg, elevation: 0,
        title: const Text('虎牙账号', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: kText),
      ),
      body: Obx(() {
        final logged = AuthState.to.loggedIn.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              child: Row(children: [
                Icon(logged ? Icons.verified_user : Icons.login,
                    color: logged ? const Color(0xFF3E9E4C) : kSub, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(logged ? '当前已登录' : '当前未登录',
                    style: TextStyle(color: logged ? const Color(0xFF3E9E4C) : kSub, fontSize: 14, fontWeight: FontWeight.w600))),
                if (logged)
                  GlassButton.custom(
                    onTap: _logout, height: 34,
                    shape: const LiquidRoundedRectangle(borderRadius: 17),
                    settings: LiquidGlassSettings(glassColor: const Color(0x33E5484D), thickness: 16, blur: 2, bodyMode: GlassBodyMode.clear),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('退出', style: TextStyle(color: Color(0xFFE5484D), fontSize: 12, fontWeight: FontWeight.w700))),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('粘贴 Cookie 登录', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('浏览器登录 huya.com → F12 → Network → 复制请求头中的 Cookie 全文粘贴到下方',
                style: TextStyle(color: kSub, fontSize: 12, height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              child: TextField(
                controller: _ctrl,
                maxLines: 6, minLines: 4,
                autocorrect: false, enableSuggestions: false,
                style: const TextStyle(color: kText, fontSize: 13, height: 1.5),
                decoration: const InputDecoration(
                  hintText: '粘贴 Cookie…', hintStyle: TextStyle(color: Color(0xFFA6ADB5)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassButton.custom(
              onTap: _saving ? null : _save,
              height: 48,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              useOwnLayer: true, quality: GlassQuality.premium,
              settings: LiquidGlassSettings(glassColor: const Color(0xE6FF8800), thickness: 24, blur: 2, bodyMode: GlassBodyMode.clear),
              child: Center(child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存登录信息', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
            ),
          ],
        );
      }),
    );
  }
}
