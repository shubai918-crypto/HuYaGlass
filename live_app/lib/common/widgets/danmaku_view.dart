import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:live_core/live_core.dart';

class DanmakuView extends StatefulWidget {
  final Stream<DanmakuMessage> danmakuStream;
  final double height;
  final int maxLines;
  final double fontSize;

  const DanmakuView({
    super.key,
    required this.danmakuStream,
    this.height = 200,
    this.maxLines = 8,
    this.fontSize = 14,
  });

  @override
  State<DanmakuView> createState() => _DanmakuViewState();
}

class _DanmakuViewState extends State<DanmakuView> {
  final List<_DanmakuItem> _items = [];
  StreamSubscription? _subscription;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _subscription = widget.danmakuStream.listen(_onDanmaku);
  }

  void _onDanmaku(DanmakuMessage msg) {
    if (!mounted) return;
    setState(() {
      _items.add(_DanmakuItem(
        message: msg,
        line: _random.nextInt(widget.maxLines),
        speed: 80 + _random.nextDouble() * 40,
      ));
      // 限制数量
      if (_items.length > 50) {
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
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: _items.map((item) {
          return _DanmakuWidget(
            item: item,
            fontSize: widget.fontSize,
            lineHeight: widget.height / widget.maxLines,
          );
        }).toList(),
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

  const _DanmakuWidget({
    required this.item,
    required this.fontSize,
    required this.lineHeight,
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
      duration: Duration(seconds: (widget.item.speed / 10).round()),
    );
    _animation = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: const Offset(-1.5, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.item.line * widget.lineHeight,
      child: SlideTransition(
        position: _animation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${widget.item.message.nickname}: ',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: widget.item.message.content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
