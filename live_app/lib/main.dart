import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import 'core/app_settings.dart';
import 'core/user_profile.dart';
import 'modules/home/home_page.dart';
import 'modules/home/follow_store.dart';
import 'modules/live_play/background_play.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await HuyaLoginManager.init();
  await BackgroundPlayStore.init();
  await FollowStore.init();

  Get.put(AppSettings(), permanent: true);
  Get.put(UserProfile(), permanent: true); // ★ 注册用户资料服务

  await LiquidGlassWidgets.initialize();

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
    return Obx(() => GetMaterialApp(
          title: 'HuyaLive',
          debugShowCheckedModeBanner: false,
          themeMode: AppSettings.to.themeMode.value,
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            colorScheme: const ColorScheme.light(primary: Color(0xFFFF8800)),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0A0A0F),
            colorScheme: const ColorScheme.dark(primary: Color(0xFFFF8800)),
          ),
          home: const HomePage(),
        ));
  }
}
