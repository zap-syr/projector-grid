import 'package:flutter/material.dart';

/// Fades the top and bottom edges of a vertical scroll view while there is
/// more content past them, so a list that continues says so. Wrap the
/// scrollable directly: the fade follows its [ScrollNotification]s.
class ScrollFade extends StatefulWidget {
  const ScrollFade({super.key, required this.child, this.extent = 24});

  final Widget child;

  /// Height of each fade.
  final double extent;

  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<ScrollFade> {
  bool _top = false;
  bool _bottom = false;

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != Axis.vertical) return false;
    final top = m.pixels > m.minScrollExtent + 0.5;
    final bottom = m.pixels < m.maxScrollExtent - 0.5;
    if (top != _top || bottom != _bottom) {
      setState(() {
        _top = top;
        _bottom = bottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final h = rect.height == 0 ? 1.0 : rect.height;
            final f = (widget.extent / h).clamp(0.0, 0.5);
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _top ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _bottom ? Colors.transparent : Colors.black,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(rect);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
