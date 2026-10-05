import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/app_settings.dart';
import 'modules/home/home_page.dart';
import 'modules/notice/notice_page.dart';
import 'modules/login/huya_login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    runApp(const HuyaLiveApp());
  });
}

class HuyaLiveApp extends StatelessWidget {
  const HuyaLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassWidgets(
      child: GetMaterialApp(
        title: 'HuyaLive',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFFF4F5F6),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8800), brightness: Brightness.light),
          useMaterial3: true,
        ),
        home: const HomePage(),
        getPages: [
          GetPage(name: '/notice', page: () => const NoticePage()),
          GetPage(name: '/huya_login', page: () => const HuyaLoginPage()),
        ],
      ),
    );
  }
}
