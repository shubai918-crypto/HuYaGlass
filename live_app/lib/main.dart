import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import 'core/app_settings.dart';
import 'core/notify_manager.dart';
import 'core/user_profile.dart';
import 'modules/home/follow_store.dart';
import 'modules/home/home_page.dart';
import 'modules/home/notice_page.dart';
import 'modules/live_play/background_play.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await HuyaLoginManager.init();
  await BackgroundPlayStore.init();
  await FollowStore.init();

  Get.put(AppSettings(), permanent: true);
  Get.put(UserProfile(), permanent: true);
  Get.put(LiveNotifyManager(), permanent: true);

  // ★ 预热 shader，消除首帧卡顿
  await LiquidGlassWidgets.initialize();

  runApp(LiquidGlassWidgets.wrap(
    child: const HuyaLiveApp(),
    brightnessResolver: Theme.maybeBrightnessOf,
  ));
}

class HuyaLiveApp extends StatelessWidget {
  const HuyaLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => GetMaterialApp(
          title: 'HuyaLive',
          debugShowCheckedModeBanner: false,
          themeMode: AppSettings.to.themeMode.value,
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F5F6),
            colorScheme: const ColorScheme.light(primary: Color(0xFFFF8800)),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0A0A0F),
            colorScheme: const ColorScheme.dark(primary: Color(0xFFFF8800)),
          ),
          // ★ 官方修复：MaterialApp 下给 glass 页面补透明 Material
          builder: (context, child) => Material(
            type: MaterialType.transparency,
            child: child!,
          ),
          getPages: [
            GetPage(name: '/notice', page: () => const NoticePage()),
          ],
          home: const SplashPage(), // ★ 启动页
        ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ★ Splash 启动页：遮住首帧 shader 编译卡顿，进入更顺滑
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
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: const Icon(Icons.live_tv, color: Color(0xFFFF7A00), size: 52),
              ),
              const SizedBox(height: 18),
              const Text('HuyaLive',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text('虎牙直播 · 液态玻璃',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
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
