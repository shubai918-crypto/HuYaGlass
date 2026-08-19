import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';
import '../../common/widgets/liquid_glass.dart';

class HuyaLoginPage extends StatefulWidget {
  const HuyaLoginPage({super.key});
  @override
  State<HuyaLoginPage> createState() => _HuyaLoginPageState();
}

class _HuyaLoginPageState extends State<HuyaLoginPage> {
  final _controller = TextEditingController();
  final _manager = HuyaLoginManager();

  @override
  void initState() {
    super.initState();
    _controller.text = _manager.cookie;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('虎牙账号登录', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiquidGlass(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('如何获取 Cookie？',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '1. 在浏览器打开 huya.com 并登录你的账号\n'
                      '2. 按 F12 打开开发者工具，切换到 Network(网络) 面板\n'
                      '3. 刷新页面，点击第一个请求\n'
                      '4. 在 Request Headers 中找到 Cookie，复制其值',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LiquidGlass(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '在此粘贴完整的虎牙 Cookie...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassButton(
                      text: _manager.isLoggedIn ? '更新并保存' : '保存登录',
                      selected: true,
                      fontSize: 14,
                      onTap: () {
                        _manager.setCookie(_controller.text);
                        setState(() {});
                        Get.snackbar('成功', 'Cookie 已保存，返回直播间将自动刷新真实粉丝数',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.greenAccent.withOpacity(0.2),
                            colorText: Colors.white);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidGlassButton(
                      text: '清除登录',
                      selected: false,
                      fontSize: 14,
                      onTap: () {
                        _manager.logout();
                        _controller.clear();
                        setState(() {});
                        Get.snackbar('成功', '已退出登录',
                            snackPosition: SnackPosition.BOTTOM);
                      },
                    ),
                  ),
                ],
              ),
              if (_manager.isLoggedIn)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text('✅ 当前已登录，发弹幕与订阅功能已解锁',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
