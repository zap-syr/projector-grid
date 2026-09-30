/// `POST /api/alignment/{op}`: the web's handle on the app's Alignment mode
/// (ROADMAP_PLAN.md §5). Each op maps to one `AlignmentNotifier` method, so
/// the web drives the same session as the banner. See
/// `web_ui/api/openapi.yaml` (`AlignmentOp`).
library;

import 'alignment.dart';

sealed class WebAlignmentOp {
  const WebAlignmentOp();
}

/// Scope as in the app: the given selection when it has two or more
/// projectors, otherwise everything.
class WebAlignmentEnter extends WebAlignmentOp {
  final Set<String> selection;
  const WebAlignmentEnter(this.selection);
}

/// The ops without arguments. The toggles flip, like the banner's buttons.
enum WebAlignmentCommand { exit, next, prev, neighbours, diagonals, showAll }

class WebAlignmentSimple extends WebAlignmentOp {
  final WebAlignmentCommand command;
  const WebAlignmentSimple(this.command);
}

class WebAlignmentFocus extends WebAlignmentOp {
  final String id;
  const WebAlignmentFocus(this.id);
}

class WebAlignmentPreset extends WebAlignmentOp {
  final AlignmentPreset preset;
  const WebAlignmentPreset(this.preset);
}

class WebAlignmentFocusedPattern extends WebAlignmentOp {
  final String code;
  const WebAlignmentFocusedPattern(this.code);
}

/// [code] null = same as focused.
class WebAlignmentOthersPattern extends WebAlignmentOp {
  final String? code;
  const WebAlignmentOthersPattern(this.code);
}

/// [op] from the path, [body] the decoded JSON (null when empty). Patterns
/// must be ones [preset] offers, as in the app's pickers. Null when
/// anything is off.
WebAlignmentOp? parseWebAlignmentOp(
  String op,
  Object? body, {
  required AlignmentPreset preset,
}) {
  if (body != null && body is! Map) return null;
  final args = body is Map ? body : const {};

  final simple = WebAlignmentCommand.values.where((c) => c.name == op);
  if (simple.isNotEmpty) {
    return args.isEmpty ? WebAlignmentSimple(simple.first) : null;
  }
  switch (op) {
    case 'enter':
      final targets = args['targets'];
      if (args.isEmpty) return const WebAlignmentEnter({});
      if (args.length != 1 ||
          targets is! List ||
          !targets.every((e) => e is String)) {
        return null;
      }
      return WebAlignmentEnter(targets.cast<String>().toSet());
    case 'focus':
      final id = args['id'];
      return args.length == 1 && id is String ? WebAlignmentFocus(id) : null;
    case 'preset':
      final match = AlignmentPreset.values.where(
        (p) => p.name == args['preset'],
      );
      return args.length == 1 && match.isNotEmpty
          ? WebAlignmentPreset(match.first)
          : null;
    case 'focusedPattern':
      final code = args['code'];
      return args.length == 1 &&
              code is String &&
              preset.patterns.contains(code)
          ? WebAlignmentFocusedPattern(code)
          : null;
    case 'othersPattern':
      final code = args['code'];
      if (args.length != 1 || !args.containsKey('code')) return null;
      if (code == null) return const WebAlignmentOthersPattern(null);
      return code is String && preset.patterns.contains(code)
          ? WebAlignmentOthersPattern(code)
          : null;
  }
  return null;
}
