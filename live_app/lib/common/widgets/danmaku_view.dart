import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:live_core/live_core.dart';

/// 滚动弹幕：FPS/速度/透明度/区域可调，空闲自动暂停（省电）
class DanmakuView extends StatefulWidget {
  final Stream<DanmakuMessage> danmakuStream;
  final double height;
  final double fontSize;
  final int fps;
  final double speed;
  final double opacity;

  const DanmakuView({
    super.key,
    required this.danmakuStream,
    this.height = 140,
    this.fontSize = 14,
    this.fps = 30,
    this.speed = 120,
    this.opacity = 1.0,
  });

  @override
  State<DanmakuView> createState() => _DanmakuViewState();
}

class _DanmakuViewState extends State<DanmakuView> {
  final List<_Fly> _flies = [];
  final Random _rnd = Random();
  Timer? _timer;
  StreamSubscription? _sub;
  double _width = 0;

  int get _fps => widget.fps.clamp(10, 60);
  int get _lanes => max(3, (widget.height / (widget.fontSize * 1.9)).floor());

  @override
  void initState() {
    super.initState();
    _sub = widget.danmakuStream.listen(_onMsg);
  }

  @override
  void didUpdateWidget(covariant DanmakuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fps != widget.fps) {
      _timer?.cancel();
      _timer = null;
      _startTimer();
    }
  }

  void _onMsg(DanmakuMessage m) {
    if (_width <= 0) return;
    _flies.add(_Fly(
      text: '${m.nickname}: ${m.content}',
      color: Color(m.fontColor),
      lane: _rnd.nextInt(_lanes),
      x: _width + 10,
      speed: widget.speed * (0.9 + _rnd.nextDouble() * 0.3),
    ));
    if (_flies.length > 60) _flies.removeRange(0, _flies.length - 60);
    _startTimer();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    final ms = 1000 ~/ _fps;
    _timer = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted || _flies.isEmpty) {
        t.cancel(); // 空闲即停，零 CPU 占用
        return;
      }
      final dt = ms / 1000.0;
      setState(() {
        for (final f in _flies) {
          f.x -= f.speed * dt;
        }
        _flies.removeWhere((f) => f.x < -(_width + 300));
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (c, cons) {
        _width = cons.maxWidth;
        final laneH = widget.height / _lanes;
        return Opacity(
          opacity: widget.opacity,
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final f in _flies)
                  Positioned(
                    left: f.x,
                    top: f.lane * laneH + 2,
                    child: Text(
                      f.text,
                      style: TextStyle(
                        color: f.color,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 2)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Fly {
  final String text;
  final Color color;
  final int lane;
  final double speed;
  double x;
  _Fly({
    required this.text,
    required this.color,
    required this.lane,
    required this.x,
    required this.speed,
  });
}
