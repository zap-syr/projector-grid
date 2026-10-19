import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/dialog_parts.dart';

/// A date typed as DD/MM/YYYY or picked from a calendar that opens from the
/// field's icon. Reports every edit: the parsed day, or null while the text
/// isn't a whole date.
///
/// The calendar is an [OverlayPortal]; [CalendarDatePicker] sits in
/// `TooltipVisibility(visible: false)` because the tooltips on its month
/// arrows call markNeedsLayout during paint and trip RenderFollowerLayer
/// assertions.
class TaskDateField extends StatefulWidget {
  const TaskDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.error = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool error;

  @override
  State<TaskDateField> createState() => _TaskDateFieldState();
}

class _TaskDateFieldState extends State<TaskDateField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value == null ? '' : _toDisplay(widget.value!),
  );
  final _focusNode = FocusNode();
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  bool _openUpward = false;

  static String _toDisplay(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  static DateTime? _parse(String text) {
    final parts = text.split('/');
    if (parts.length != 3 || parts[2].length != 4) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    final dt = DateTime(y, m, d);
    // DateTime rolls 31/02 over into March; that isn't the date typed.
    if (dt.month != m || dt.day != d) return null;
    return dt;
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _lastDate => _today.add(const Duration(days: 365 * 5));

  DateTime _clampedInitial() {
    final date = widget.value ?? _today;
    if (date.isBefore(_today)) return _today;
    if (date.isAfter(_lastDate)) return _lastDate;
    return date;
  }

  @override
  void didUpdateWidget(TaskDateField old) {
    super.didUpdateWidget(old);
    final value = widget.value;
    if (old.value != value && value != null && !_focusNode.hasFocus) {
      _ctrl.text = _toDisplay(value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleCalendar() {
    if (_portal.isShowing) {
      _portal.hide();
    } else {
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.hasSize) {
        final bottom = ro.localToGlobal(Offset(0, ro.size.height));
        _openUpward = MediaQuery.sizeOf(context).height - bottom.dy < 340;
      }
      _portal.show();
    }
    setState(() {});
  }

  void _hide() {
    _portal.hide();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final open = _portal.isShowing;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (_) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hide,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: _openUpward
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: _openUpward
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              offset: Offset(0, _openUpward ? -4 : 4),
              showWhenUnlinked: false,
              child: RepaintBoundary(
                child: Material(
                  elevation: 8,
                  color: cs.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: SizedBox(
                    width: 300,
                    child: TooltipVisibility(
                      visible: false,
                      child: CalendarDatePicker(
                        initialDate: _clampedInitial(),
                        firstDate: _today,
                        lastDate: _lastDate,
                        onDateChanged: (dt) {
                          _ctrl.text = _toDisplay(dt);
                          widget.onChanged(dt);
                          _hide();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          style: monoFieldStyle,
          inputFormatters: [_DateInputFormatter()],
          decoration:
              dialogFieldDecoration(
                context,
                hintText: 'DD/MM/YYYY',
                error: widget.error,
              ).copyWith(
                prefixIcon: IconButton(
                  tooltip: 'Pick a date',
                  icon: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: open ? cs.primary : cs.onSurfaceVariant,
                  ),
                  onPressed: _toggleCalendar,
                ),
              ),
          onChanged: (text) => widget.onChanged(_parse(text)),
        ),
      ),
    );
  }
}

/// Keeps digits only and puts the slashes in: `18102026` → `18/10/2026`.
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    final digits = value.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    final count = digits.length.clamp(0, 8);
    for (var i = 0; i < count; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
