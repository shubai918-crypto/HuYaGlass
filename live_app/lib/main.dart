import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'modules/home/home_page.dart';

// ★ 请根据你项目的实际路径修改这两个 import！
// 如果报错找不到，请改成类似 'modules/home/notice_page.dart' 或 'modules/login/huya_login_page.dart'
import 'modules/home/notice_page.dart'; 
import 'modules/settings/huya_login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ★ 预热 Shader，防止首帧白屏卡顿
  await LiquidGlassWidgets.initialize(); 
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    runApp(const HuyaLiveApp());
  });
}

class HuyaLiveApp extends StatelessWidget {
  const HuyaLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ★ 直接返回 GetMaterialApp，避免和 LiquidGlassWidgets.wrap 冲突导致嵌套 MaterialApp
    return GetMaterialApp(
      title: 'HuyaLive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F5F6),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8800), brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const SplashPage(),
      getPages: [
        GetPage(name: '/notice', page: () => const NoticePage()),
        GetPage(name: '/huya_login', page: () => const HuyaLoginPage()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash 启动页
// ─────────────────────────────────────────────────────────────────────────────
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _ac.forward();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Get.offAll(() => const HomePage());
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF7A00),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF9A2E), Color(0xFFFF6A00)],
          ),
        ),
        child: SafeArea(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: const Icon(Icons.live_tv, color: Color(0xFFFF7A00), size: 52),
              ),
              const SizedBox(height: 18),
              const Text('HuyaLive',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text('虎牙直播 · 液态玻璃', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text('看直播 · 弹幕 · 订阅 · 真实发送',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
