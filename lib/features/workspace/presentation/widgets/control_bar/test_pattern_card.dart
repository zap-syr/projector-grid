import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/services/app_config_dir.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/test_patterns.dart';
import '../common/dashed_border.dart';
import '../custom_tooltip.dart';
import 'control_bar_parts.dart';

/// A test pattern's thumbnail (the existing pattern icons).
Widget testPatternThumbnail(String code, {double size = 18}) {
  final path = kTestPatternIcons[code];
  if (path == null) return SizedBox.square(dimension: size);
  return ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SvgPicture.asset(path, width: size, height: size),
  );
}

/// Off, four favourite slots and the pattern dropdown with *Show*.
///
/// Favourites live in `test_pattern_favorites.json`: an empty slot adds the
/// pattern picked in the dropdown (unless it's already a favourite), a
/// filled slot shows its pattern, Ctrl+click clears it.
class TestPatternCard extends ConsumerStatefulWidget {
  const TestPatternCard({super.key});

  static const int slotCount = 4;
  static const double slotWidth = 44;
  static const double rowHeight = ControlBarMetrics.commandButtonHeight;

  @override
  ConsumerState<TestPatternCard> createState() => _TestPatternCardState();
}

class _TestPatternCardState extends ConsumerState<TestPatternCard> {
  static final _items = dropdownItems(
    kTestPatternLabels,
    leading: (code) => testPatternThumbnail(code),
  );

  String _selected = 'OTS:01';
  final List<String?> _favorites = List.filled(TestPatternCard.slotCount, null);

  static String get _favoritesFilePath =>
      appConfigFilePath('test_pattern_favorites.json');

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    try {
      final file = File(_favoritesFilePath);
      if (!file.existsSync()) return;
      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      for (int i = 0; i < _favorites.length && i < list.length; i++) {
        final val = list[i];
        if (val is String && kTestPatternLabels.containsKey(val)) {
          _favorites[i] = val;
        }
      }
    } catch (_) {}
  }

  void _saveFavorites() {
    try {
      final file = File(_favoritesFilePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_favorites));
    } catch (_) {}
  }

  void _addFavorite(int index) {
    if (_favorites[index] != null) return;
    if (_favorites.contains(_selected)) return;
    setState(() => _favorites[index] = _selected);
    _saveFavorites();
  }

  void _clearFavorite(int index) {
    setState(() => _favorites[index] = null);
    _saveFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final canAddSelected = !_favorites.contains(_selected);
    return ControlBarCard(
      icon: Icons.grid_on,
      title: 'Test pattern',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: TestPatternCard.rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CommandButton(
                    key: const ValueKey('test-pattern-off'),
                    label: 'Off',
                    icon: Icons.grid_off,
                    iconColor: Theme.of(context).colorScheme.error,
                    height: TestPatternCard.rowHeight,
                    onPressed: () => sendToSelected(ref, kTestPatternOff),
                  ),
                ),
                for (int i = 0; i < _favorites.length; i++) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    key: ValueKey('favorite-slot-$i'),
                    width: TestPatternCard.slotWidth,
                    child: _FavoriteSlot(
                      code: _favorites[i],
                      selectedLabel: kTestPatternLabels[_selected],
                      onShow: () => sendToSelected(ref, _favorites[i]!),
                      onAdd: _favorites[i] == null && canAddSelected
                          ? () => _addFavorite(i)
                          : null,
                      onClear: () => _clearFavorite(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          DropdownSendRow<String>(
            items: _items,
            value: _selected,
            sendLabel: 'Show',
            menuHeight: 300,
            onChanged: (v) => setState(() => _selected = v),
            onSend: () => sendToSelected(ref, _selected),
          ),
        ],
      ),
    );
  }
}

/// One favourite slot. Empty: dashed with a +, adds the picked pattern.
/// Filled: the pattern's thumbnail; click shows it, Ctrl+click clears it.
/// Both are the same size, so filling or clearing a slot moves nothing.
class _FavoriteSlot extends StatelessWidget {
  const _FavoriteSlot({
    required this.code,
    required this.selectedLabel,
    required this.onShow,
    required this.onAdd,
    required this.onClear,
  });

  final String? code;
  final String? selectedLabel;
  final VoidCallback onShow;
  final VoidCallback? onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final code = this.code;
    if (code == null) {
      final add = onAdd;
      final slot = DashedBorder(
        radius: 10,
        color: add == null ? t.disabled : t.tertiary,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: add,
            child: Center(
              child: Icon(
                Icons.add,
                size: 16,
                color: add == null ? t.disabled : t.secondary,
              ),
            ),
          ),
        ),
      );
      final label = selectedLabel;
      return add == null || label == null
          ? slot
          : CustomTooltip(
              message: 'Add to favorites',
              detail: label,
              child: slot,
            );
    }
    return CustomTooltip(
      message: kTestPatternLabels[code] ?? code,
      detail: 'Ctrl click to remove',
      child: OutlinedButton(
        style: commandButtonStyle(
          context,
          height: TestPatternCard.rowHeight,
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          if (HardwareKeyboard.instance.isControlPressed) {
            onClear();
          } else {
            onShow();
          }
        },
        child: testPatternThumbnail(code, size: 20),
      ),
    );
  }
}
