import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/routes.dart';
import 'app/theme.dart';
import 'common/services/login_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 初始化 Hive
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('follow');
  } catch (e) {
    // Hive 初始化失败也不阻塞启动
    debugPrint('Hive init error: $e');
  }

  // 锁定竖屏
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 透明状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 注册全局服务（必须在 runApp 之前）
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
