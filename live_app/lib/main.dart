import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import 'modules/home/home_page.dart';
import 'modules/live_play/live_play_page.dart';
import 'modules/settings/huya_login_page.dart';
import 'modules/settings/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // 恢复虎牙登录态（磁盘持久化）
  await HuyaLoginManager.init();

  // liquid_glass_widgets：非阻塞初始化，防止首帧玻璃白闪
  await LiquidGlassWidgets.initialize(warmUpMode: GlassWarmUpMode.auto);

  runApp(
    LiquidGlassWidgets.wrap(
      child: const HuyaLiveApp(),
      brightnessResolver: Theme.maybeBrightnessOf,
    ),
  );
}

class HuyaLiveApp extends StatelessWidget {
  const HuyaLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HuyaLive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00D2FF)),
      ),
      home: const HomePage(),
      routes: {
        '/live': (_) => const LivePlayPage(),
        '/settings': (_) => const SettingsPage(),
        '/login': (_) => const HuyaLoginPage(),
      },
    );
  }
}
