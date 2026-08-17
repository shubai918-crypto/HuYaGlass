import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:live_core/live_core.dart';

/// 弹幕滚动视图
class DanmakuView extends StatefulWidget {
  final Stream<DanmakuMessage> danmakuStream;
  final double height;
  final int maxLines;
  final double fontSize;
  final bool enabled;

  const DanmakuView({
    super.key,
    required this.danmakuStream,
    this.height = 220,
    this.maxLines = 8,
    this.fontSize = 14,
    this.enabled = true,
  });

  @override
  State<DanmakuView> createState() => _DanmakuViewState();
}

class _DanmakuViewState extends State<DanmakuView> {
  final List<_DanmakuItem> _items = [];
  StreamSubscription? _subscription;
  final Random _random = Random();
  final List<double> _lineEndTimes = [];

  @override
  void initState() {
    super.initState();
    _lineEndTimes.addAll(List.filled(widget.maxLines, 0));
    _subscription = widget.danmakuStream.listen(_onDanmaku);
  }

  void _onDanmaku(DanmakuMessage msg) {
    if (!mounted || !widget.enabled) return;

    // 选择最空闲的行
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    int bestLine = 0;
    double minEnd = double.infinity;
    for (int i = 0; i < widget.maxLines; i++) {
      if (_lineEndTimes[i] < minEnd) {
        minEnd = _lineEndTimes[i];
        bestLine = i;
      }
    }

    setState(() {
      _items.add(_DanmakuItem(
        message: msg,
        line: bestLine,
        speed: 6 + _random.nextDouble() * 4, // 6~10 秒
      ));
      _lineEndTimes[bestLine] = now + 2000; // 避免重叠

      // 限制数量
      if (_items.length > 60) {
        _items.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: _items.map((item) {
            return _DanmakuWidget(
              key: ValueKey(item.hashCode),
              item: item,
              fontSize: widget.fontSize,
              lineHeight: widget.height / widget.maxLines,
              onComplete: () {
                if (mounted) {
                  setState(() => _items.remove(item));
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DanmakuItem {
  final DanmakuMessage message;
  final int line;
  final double speed;

  _DanmakuItem({
    required this.message,
    required this.line,
    required this.speed,
  });
}

class _DanmakuWidget extends StatefulWidget {
  final _DanmakuItem item;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onComplete;

  const _DanmakuWidget({
    super.key,
    required this.item,
    required this.fontSize,
    required this.lineHeight,
    required this.onComplete,
  });

  @override
  State<_DanmakuWidget> createState() => _DanmakuWidgetState();
}

class _DanmakuWidgetState extends State<_DanmakuWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.item.speed.round()),
    );
    _animation = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: const Offset(-2.0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.item.message;
    return Positioned(
      top: widget.item.line * widget.lineHeight,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _animation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${msg.nickname}: ',
                  style: TextStyle(
                    color: const Color(0xFF00D2FF),
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: msg.content,
                  style: TextStyle(
                    color: msg.fontColor >= 0
                        ? Color(msg.fontColor | 0xFF000000)
                        : Colors.white,
                    fontSize: widget.fontSize,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
