import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'app/routes.dart';
import 'app/theme.dart';
import 'common/services/login_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 初始化 media_kit 播放器引擎 (必须在 runApp 之前)
  MediaKit.ensureInitialized();

  // 2. 安全初始化 Hive 本地存储
  try {
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('follow');
  } catch (e) {
    debugPrint('Hive init error: $e');
  }

  // 3. 锁定竖屏
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 4. 透明状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 5. 注册全局登录服务
  Get.put(LoginService(), permanent: true);

  runApp(const MyApp());
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
