import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import 'modules/home/home_page.dart';
import 'modules/live_play/background_play.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await HuyaLoginManager.init();
  await BackgroundPlayStore.init(); // ★ 后台播放开关初始化

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
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF8800)),
      ),
      home: const HomePage(),
    );
  }
}
