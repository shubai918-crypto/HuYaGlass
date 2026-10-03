import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HUYA LIVE PALETTE & GLASS SETTINGS
// ─────────────────────────────────────────────────────────────────────────────

const kHuyaOrange = Color(0xFFFF8800);
const kHuyaCyan = Color(0xFF00D2FF);

/// 极暗背景 (匹配首页的 RadialGradient 底色)
const kHuyaBg = Color(0xFF050508);

/// 卡片背景 (Inset Grouped 风格，深色下为实色，遵循 Rule 1 & 2)
const kHuyaCardBg = CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.white,
  darkColor: Color(0xFF16161E),
);

/// 分割线
const kHuyaDivider = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFE5E5EA),
  darkColor: Color(0xFF2C2C2E),
);

/// 全局 iOS 27 材质开关 (Notifier)
final ValueNotifier<bool> kHuyaUseIos27 = ValueNotifier<bool>(true);

/// Scope 用于在 Widget 树中传递 iOS 27 开关状态
class HuyaGlassScope extends InheritedNotifier<ValueNotifier<bool>> {
  HuyaGlassScope({super.key, ValueNotifier<bool>? notifier, required super.child})
      : super(notifier: notifier ?? kHuyaUseIos27);

  static bool isIos27(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HuyaGlassScope>();
    return (scope?.notifier ?? kHuyaUseIos27).value;
  }

  static ValueNotifier<bool> of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HuyaGlassScope>()?.notifier ?? kHuyaUseIos27;
  }
}

/// 统一的 Glass 预设 (自动适配 iOS 27 / iOS 26 和 明暗模式)
LiquidGlassSettings kHuyaGlass(BuildContext context) {
  final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
  if (HuyaGlassScope.isIos27(context)) {
    // ★ 使用 1.8.0 的 iOS 27 原生材质预设 (包含 frost, rim 光学等)
    return isDark ? LiquidGlassSettings.ios27Dark : LiquidGlassSettings.ios27Light;
  }
  // iOS 26 经典液态玻璃 fallback
  return LiquidGlassSettings(
    glassColor: isDark ? const Color(0x4D16161E) : CupertinoColors.white.withValues(alpha: 0.2),
    thickness: 22.0,
    blur: isDark ? 2.0 : 10.0,
    lightIntensity: isDark ? 0.2 : 0.5,
    refractiveIndex: 1.15,
    saturation: 1.2,
  );
}
