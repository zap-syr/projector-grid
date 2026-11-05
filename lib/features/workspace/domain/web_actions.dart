/// `POST /api/actions`: a small fixed vocabulary of actions the Web API maps
/// to NTCONTROL, so a page can't send arbitrary commands (e.g. a factory
/// reset). See `web_ui/api/openapi.yaml` (`ActionRequest`).
library;

import 'control_options.dart';
import 'lens_commands.dart';
import 'test_patterns.dart';

sealed class WebTargets {
  const WebTargets();
}

class WebTargetIds extends WebTargets {
  final List<String> ids;
  const WebTargetIds(this.ids);
}

class WebTargetGroup extends WebTargets {
  final String groupId;
  const WebTargetGroup(this.groupId);
}

class WebTargetAll extends WebTargets {
  const WebTargetAll();
}

sealed class WebAction {
  const WebAction();
}

/// An action the server sends to the projectors as [command].
class WebCommandAction extends WebAction {
  final String command;

  /// A lens motor step: never confirmed, repeated while a button is held,
  /// and throttled per projector by the server.
  final bool isLensStep;

  const WebCommandAction(this.command, {this.isLensStep = false});
}

/// `{"lensLock": true | false}`: the app's own Lens lock, nothing is sent
/// to the projectors.
class WebLensLockAction extends WebAction {
  final bool locked;
  const WebLensLockAction(this.locked);
}

typedef WebActionRequest = ({WebTargets targets, WebAction action});

/// `{"targets": …, "action": …}`; null when anything is off.
WebActionRequest? parseWebActionRequest(Object? json) {
  if (json is! Map) return null;
  final targets = _parseTargets(json['targets']);
  final action = parseWebAction(json['action']);
  if (targets == null || action == null) return null;
  return (targets: targets, action: action);
}

/// `[ids]`, `{"group": id}` or `"all"`.
WebTargets? _parseTargets(Object? json) {
  if (json == 'all') return const WebTargetAll();
  if (json is List && json.isNotEmpty && json.every((e) => e is String)) {
    return WebTargetIds(json.cast<String>());
  }
  if (json is Map && json.length == 1 && json['group'] is String) {
    return WebTargetGroup(json['group'] as String);
  }
  return null;
}

const _lensAxes = {
  'shiftH': LensAxis.shiftH,
  'shiftV': LensAxis.shiftV,
  'focus': LensAxis.focus,
  'zoom': LensAxis.zoom,
};

/// One action object → its NTCONTROL command; null for anything outside
/// the vocabulary.
WebAction? parseWebAction(Object? json) {
  if (json is! Map) return null;
  final power = json['power'];
  final shutter = json['shutter'];
  final pattern = json['testPattern'];
  final lens = json['lens'];

  if (json.length == 1 && json.containsKey('lensLock')) {
    final locked = json['lensLock'];
    return locked is bool ? WebLensLockAction(locked) : null;
  }
  if (json.length == 1 && power != null) {
    return switch (power) {
      'on' => const WebCommandAction('PON'),
      'off' => const WebCommandAction('POF'),
      _ => null,
    };
  }
  if (json.length == 1 && shutter != null) {
    return switch (shutter) {
      'open' => const WebCommandAction('OSH:0'),
      'close' => const WebCommandAction('OSH:1'),
      _ => null,
    };
  }
  if (json.length == 1 && pattern is String) {
    final known =
        pattern == kTestPatternOff || kTestPatternLabels.containsKey(pattern);
    return known ? WebCommandAction(pattern) : null;
  }
  if (json.length == 1 && json['osd'] != null) {
    return switch (json['osd']) {
      'on' => const WebCommandAction('OOS:1'),
      'off' => const WebCommandAction('OOS:0'),
      _ => null,
    };
  }
  // Dropdown choices: the command itself, but only one the app offers.
  for (final (key, options) in [
    ('input', kInputOptions),
    ('lensCalibration', kLensCalibrationOptions),
    ('lensType', kLensTypeOptions),
  ]) {
    final code = json[key];
    if (json.length == 1 && code != null) {
      return code is String && options.containsKey(code)
          ? WebCommandAction(code)
          : null;
    }
  }
  if (json.length == 1 && lens == 'home') {
    return const WebCommandAction(kLensHomeCommand);
  }
  final axis = _lensAxes[lens];
  final dir = json['dir'];
  final speed = LensSpeed.values
      .where((s) => s.name == json['speed'])
      .firstOrNull;
  if (json.length == 3 && axis != null && speed != null) {
    if (dir != '+' && dir != '-') return null;
    return WebCommandAction(
      lensStepCommand(axis, plus: dir == '+', speed: speed),
      isLensStep: true,
    );
  }
  return null;
}
