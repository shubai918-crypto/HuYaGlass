import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'app/routes.dart';
import 'app/theme.dart';
import 'common/services/login_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 播放器引擎
  MediaKit.ensureInitialized();

  // 液态玻璃：预热着色器，消除首帧白闪
  await LiquidGlassWidgets.initialize();

  try {
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('follow');
  } catch (e) {
    debugPrint('Hive init error: $e');
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  Get.put(LoginService(), permanent: true);

  runApp(LiquidGlassWidgets.wrap(
    child: const MyApp(),
    brightnessResolver: Theme.maybeBrightnessOf,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HuyaLive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.home,
    );
  }
}
