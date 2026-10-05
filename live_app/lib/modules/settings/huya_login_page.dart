import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';

import '../home/home_page.dart';

class HuyaLoginPage extends StatefulWidget {
  const HuyaLoginPage({super.key});
  @override
  State<HuyaLoginPage> createState() => _HuyaLoginPageState();
}

class _HuyaLoginPageState extends State<HuyaLoginPage> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = HuyaLoginManager().cookie;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      Get.snackbar('提示', '请先粘贴 Cookie', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _saving = true);
    try {
      // ★ 若你的 HuyaLoginManager 保存方法名不同（login / setCookie），只改这一行
      await HuyaLoginManager().saveCookie(v);
      Get.snackbar('成功', '登录信息已保存', snackPosition: SnackPosition.BOTTOM);
      Get.back();
    } catch (e) {
      Get.snackbar('错误', '$e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    await HuyaLoginManager().logout();
    _ctrl.clear();
    Get.snackbar('提示', '已清除登录', snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kText),
        title: const Text('虎牙登录', style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('如何获取 Cookie？', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                '1. 在浏览器打开 huya.com 并登录你的账号\n2. 按 F12 打开开发者工具，切换到 Network 面板\n3. 刷新页面，点击第一个请求\n4. 在 Request Headers 中找到 Cookie，复制其值',
                style: TextStyle(color: kSub, fontSize: 13, height: 1.7),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            height: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(color: kText, fontSize: 13),
              decoration: const InputDecoration(
                hintText: '在此粘贴完整的虎牙 Cookie...',
                hintStyle: TextStyle(color: Color(0xFFA6ADB5), fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('保存登录',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _clear,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                  child: const Center(
                      child: Text('清除登录', style: TextStyle(color: kSub, fontSize: 15, fontWeight: FontWeight.w600))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
