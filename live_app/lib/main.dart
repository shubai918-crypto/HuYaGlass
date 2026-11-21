import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import 'core/app_settings.dart';
import 'core/auth_state.dart';
import 'core/notify_manager.dart';
import 'core/ui_prefs.dart';
import 'core/user_profile.dart';
import 'modules/home/follow_store.dart';
import 'modules/home/home_page.dart';
import 'modules/home/notice_page.dart';
import 'modules/live_play/background_play.dart';
import 'modules/settings/huya_login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ★★★ 初始化块不能删：订阅/我的/直播页依赖这些注册，删了灰屏报 not found
  await HuyaLoginManager.init();
  await BackgroundPlayStore.init();
  await FollowStore.init();
  Get.put(AppSettings(), permanent: true);
  Get.put(UserProfile(), permanent: true);
  Get.put(LiveNotifyManager(), permanent: true);
  Get.put(AuthState(), permanent: true);
  Get.put(UiPrefs(), permanent: true); // ★ 新增：minimal 省电玻璃开关
  AuthState.to.refresh();

  // ★ 登录态双向同步桥：AuthState ↔ UserProfile，任一处更新另一处即时跟随
  //   （带 syncing 守卫防循环；保证首页/我的 Obx 立即刷新，无需重启）
  var syncing = false;
  ever<bool>(AuthState.to.loggedIn, (v) {
    if (syncing) return;
    syncing = true;
    if (v) {
      UserProfile.to.logged.value = true;
    } else {
      UserProfile.to.clear();
    }
    syncing = false;
  });
  ever<bool>(UserProfile.to.logged, (v) {
    if (syncing) return;
    syncing = true;
    AuthState.to.loggedIn.value = v;
    syncing = false;
  });

  // 预热 shader，遮首帧卡顿
  await LiquidGlassWidgets.initialize();

  runApp(const HuyaLiveApp());
}

class HuyaLiveApp extends StatelessWidget {
  const HuyaLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HuyaLive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F5F6),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8800), brightness: Brightness.light),
        useMaterial3: true,
      ),
      // ★ GlassTheme 包裹：minimal ↔ ios27 一键切换；内层 Material 透明兜底消灭黄下划线
      builder: (context, child) => Obx(() => GlassTheme(
            data: UiPrefs.to.minimalGlass.value
                ? const GlassThemeData(
                    light: GlassThemeVariant.minimalLight,
                    dark: GlassThemeVariant.minimalDark,
                  )
                : const GlassThemeData.ios27(),
            child: Material(type: MaterialType.transparency, child: child!),
          )),
      home: const SplashPage(),
      getPages: [
        GetPage(name: '/notice', page: () => const NoticePage()),
        GetPage(name: '/huya_login', page: () => HuyaLoginPage()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash 启动页：虎牙橙渐变 + Logo 缩放动画
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
