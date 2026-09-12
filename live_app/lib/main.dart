import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/live_core.dart';

import 'core/app_settings.dart'; // ★ 新增：导入全局设置服务
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

  // ★ 注册全局设置服务（主题模式、调试开关），设为 permanent 防止被意外回收
  Get.put(AppSettings(), permanent: true);

  // ★ 1.0.0：初始化参数精简，着色器预热与无障碍检测由底层自动完成
  await LiquidGlassWidgets.initialize();

  runApp(
    LiquidGlassWidgets.wrap(
      child: const HuyaLiveApp(),
      // 自动根据当前 ThemeMode 解析亮度，让玻璃组件完美适配明暗主题
      brightnessResolver: Theme.maybeBrightnessOf, 
    ),
  );
}

class HuyaLiveApp extends StatelessWidget {
  const HuyaLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ★ 使用 Obx 监听主题模式变化，实现无缝切换
    return Obx(() => GetMaterialApp(
          title: 'HuyaLive',
          debugShowCheckedModeBanner: false,
          themeMode: AppSettings.to.themeMode.value, // 绑定当前主题模式
          
          // 浅色主题配置
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            colorScheme: const ColorScheme.light(primary: Color(0xFFFF8800)),
          ),
          
          // 深色主题配置（保留你原本优秀的深色配色）
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
