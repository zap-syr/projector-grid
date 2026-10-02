import 'package:flutter/material.dart';

/// A panel row of known height, so the area can tell how many are hidden.
typedef AlertScrollEntry = ({Widget child, double height, bool counts});

/// The alert panels' list: scrolls past [maxHeight] or past the height its
/// parent leaves it (put it in a `Flexible`), fades the edge where rows are
/// hidden, and says how many rows are below the fold.
class AlertScrollArea extends StatefulWidget {
  const AlertScrollArea({
    super.key,
    required this.entries,
    required this.maxHeight,
    this.gap = 3,
  });

  /// [AlertScrollEntry.counts] marks what "N more below" counts: alert rows
  /// and lines, not section headers.
  final List<AlertScrollEntry> entries;
  final double maxHeight;
  final double gap;

  @override
  State<AlertScrollArea> createState() => _AlertScrollAreaState();
}

class _AlertScrollAreaState extends State<AlertScrollArea> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _contentHeight {
    final n = widget.entries.length;
    if (n == 0) return 0;
    return widget.entries.fold<double>(0, (sum, e) => sum + e.height) +
        widget.gap * (n - 1);
  }

  /// Rows whose top is below the visible bottom edge.
  int _hiddenBelow(double viewport) {
    final offset = _controller.hasClients ? _controller.offset : 0.0;
    final bottom = offset + viewport - 8;
    var top = 0.0;
    var hidden = 0;
    for (final e in widget.entries) {
      if (top > bottom && e.counts) hidden++;
      top += e.height + widget.gap;
    }
    return hidden;
  }

  /// Room the "N more below" line takes under the list.
  static const double _moreLine = 18;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final limit = constraints.maxHeight < widget.maxHeight
          ? constraints.maxHeight
          : widget.maxHeight;
      final content = _contentHeight;
      // When it scrolls, the line below needs its room inside the limit.
      final viewport = content <= limit
          ? content
          : (limit - _moreLine).clamp(0.0, limit);
      return _build(context, content, viewport);
    },
  );

  Widget _build(BuildContext context, double content, double viewport) {
    final theme = Theme.of(context);
    final offset = _controller.hasClients ? _controller.offset : 0.0;
    final fadeTop = offset > 2;
    final fadeBottom = offset + viewport < content - 2;
    final below = fadeBottom ? _hiddenBelow(viewport) : 0;

    final list = SizedBox(
      height: viewport,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final h = rect.height;
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fadeTop ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              fadeBottom ? Colors.transparent : Colors.black,
            ],
            stops: [0, (28 / h).clamp(0, 0.5), 1 - (36 / h).clamp(0, 0.5), 1],
          ).createShader(rect);
        },
        child: ListView.separated(
          controller: _controller,
          padding: EdgeInsets.zero,
          itemCount: widget.entries.length,
          separatorBuilder: (_, _) => SizedBox(height: widget.gap),
          itemBuilder: (_, i) => SizedBox(
            height: widget.entries[i].height,
            child: widget.entries[i].child,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        list,
        // Kept, empty, at the end of the list too, so the panel's height
        // doesn't change while scrolling.
        if (content > viewport)
          SizedBox(
            height: _moreLine,
            child: Center(
              child: Text(
                below > 0 ? '$below more below' : '',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.2,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.75,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
