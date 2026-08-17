import 'dart:ui';
import 'package:flutter/material.dart';

/// 液态玻璃容器（参考 AndroidLiquidGlass 项目）
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool showBorder;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 24,
    this.opacity = 0.12,
    this.padding,
    this.margin,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: showBorder
                  ? Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃按钮
class LiquidGlassButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool selected;
  final double fontSize;
  final Color? selectedColor;

  const LiquidGlassButton({
    super.key,
    required this.text,
    required this.onTap,
    this.selected = false,
    this.fontSize = 13,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? const Color(0xFF00D2FF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withOpacity(0.5)
                : Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? accent : Colors.white70,
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃图标按钮
class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: color ?? Colors.white,
        ),
      ),
    );
  }
}
