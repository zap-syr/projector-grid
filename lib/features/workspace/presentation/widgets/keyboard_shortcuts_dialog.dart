import 'package:flutter/material.dart';

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SizedBox(
        width: 560,
        height: 620,
        child: Column(
          children: [
            // Title bar
            Container(
              color: colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.only(left: 20, right: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  Text(
                    'Keyboard Shortcuts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Section(
                      title: 'Project',
                      shortcuts: [
                        _Shortcut(keys: ['Ctrl', 'N'], description: 'New project'),
                        _Shortcut(keys: ['Ctrl', 'O'], description: 'Open project'),
                        _Shortcut(keys: ['Ctrl', 'S'], description: 'Save project'),
                        _Shortcut(keys: ['Ctrl', 'Shift', 'S'], description: 'Save project as…'),
                        _Shortcut(keys: ['Ctrl', 'Q'], description: 'Exit application'),
                        _Shortcut(keys: ['F5'], description: 'Refresh all projectors'),
                      ],
                    ),
                    _Section(
                      title: 'Canvas Navigation',
                      shortcuts: [
                        _Shortcut(keys: ['Middle drag'], description: 'Pan the canvas'),
                        _Shortcut(keys: ['Ctrl', 'Scroll'], description: 'Zoom in / out (50 – 200%)'),
                        _Shortcut(keys: ['Click', 'empty space'], description: 'Deselect all'),
                      ],
                    ),
                    _Section(
                      title: 'Selection',
                      shortcuts: [
                        _Shortcut(keys: ['Click'], description: 'Select projector (deselects others)'),
                        _Shortcut(keys: ['Ctrl', 'Click'], description: 'Toggle projector in selection'),
                        _Shortcut(keys: ['Ctrl', 'Drag'], description: 'Marquee (box) select'),
                        _Shortcut(keys: ['Ctrl', 'A'], description: 'Select all projectors'),
                        _Shortcut(keys: ['Ctrl', 'D'], description: 'Deselect all projectors'),
                      ],
                    ),
                    _Section(
                      title: 'Projector Control',
                      shortcuts: [
                        _Shortcut(keys: ['I'], description: 'Open shutter on selected projectors'),
                        _Shortcut(keys: ['O'], description: 'Close shutter on selected projectors'),
                        _Shortcut(keys: ['Delete'], description: 'Delete selected projectors'),
                      ],
                    ),
                    _Section(
                      title: 'Edit',
                      shortcuts: [
                        _Shortcut(keys: ['Ctrl', 'Z'], description: 'Undo'),
                        _Shortcut(keys: ['Ctrl', 'Y'], description: 'Redo'),
                      ],
                    ),
                    _Section(
                      title: 'Lens Shift',
                      shortcuts: [
                        _Shortcut(keys: ['↑ ↓ ← →'], description: 'Lens shift — normal speed'),
                        _Shortcut(keys: ['Shift', '↑ ↓ ← →'], description: 'Lens shift — fast speed'),
                        _Shortcut(keys: ['Ctrl', '↑ ↓ ← →'], description: 'Lens shift — slow speed'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<_Shortcut> shortcuts;

  const _Section({required this.title, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: colorScheme.primary,
              ),
            ),
          ),
          ...shortcuts.map((s) => s.build(context)),
        ],
      ),
    );
  }
}

// ── Shortcut row ──────────────────────────────────────────────────────────────

class _Shortcut {
  final List<String> keys;
  final String description;

  const _Shortcut({required this.keys, required this.description});

  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: keys.map((k) => _KeyBadge(label: k)).toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Key badge ─────────────────────────────────────────────────────────────────

class _KeyBadge extends StatelessWidget {
  final String label;

  const _KeyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSingleSymbol = label.length == 1 ||
        label == '↑' || label == '↓' || label == '←' || label == '→' ||
        label == '↑ ↓ ← →';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSingleSymbol ? 8 : 10,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            offset: const Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.5,
        ),
      ),
    );
  }
}
