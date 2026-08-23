import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 后台播放开关（全局持久化）
class BackgroundPlayStore {
  static const _key = 'huya_background_play';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    enabled.value = sp.getBool(_key) ?? false;
  }

  static Future<void> set(bool v) async {
    enabled.value = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, v);
  }
}

/// 控件行里的"后台播放"开关按钮
class BackgroundPlayToggleButton extends StatelessWidget {
  const BackgroundPlayToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BackgroundPlayStore.enabled,
      builder: (context, on, _) => IconButton(
        tooltip: on ? '后台播放：开' : '后台播放：关',
        icon: Icon(
          on ? Icons.headphones : Icons.headphones_outlined,
          color: on ? const Color(0xFF00D2FF) : Colors.white54,
        ),
        onPressed: () => BackgroundPlayStore.set(!on),
      ),
    );
  }
}

/// 生命周期守卫：退后台时按开关决定是否暂停
class BackgroundPlayGuard extends StatefulWidget {
  final VoidCallback onPause;
  final VoidCallback? onResume;
  final Widget child;

  const BackgroundPlayGuard({
    super.key,
    required this.onPause,
    required this.child,
    this.onResume,
  });

  @override
  State<BackgroundPlayGuard> createState() => _BackgroundPlayGuardState();
}

class _BackgroundPlayGuardState extends State<BackgroundPlayGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!BackgroundPlayStore.enabled.value) widget.onPause();
        break;
      case AppLifecycleState.resumed:
        widget.onResume?.call();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
