import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/web_actions.dart';

void main() {
  group('parseWebAction', () {
    String? cmd(Object? json) => parseWebAction(json)?.command;

    test('power, shutter, test pattern', () {
      expect(cmd({'power': 'on'}), 'PON');
      expect(cmd({'power': 'off'}), 'POF');
      expect(cmd({'shutter': 'open'}), 'OSH:0');
      expect(cmd({'shutter': 'close'}), 'OSH:1');
      expect(cmd({'testPattern': 'OTS:07'}), 'OTS:07');
      expect(cmd({'testPattern': 'OTS:00'}), 'OTS:00');
    });

    test(
      'OSD, input, lens calibration and lens type from the app\'s lists',
      () {
        expect(cmd({'osd': 'on'}), 'OOS:1');
        expect(cmd({'osd': 'off'}), 'OOS:0');
        expect(cmd({'input': 'IIS:SD1'}), 'IIS:SD1');
        expect(
          cmd({'lensCalibration': 'VXX:LNSI0=+00012'}),
          'VXX:LNSI0=+00012',
        );
        expect(cmd({'lensType': 'VXX:LNEI1=+00009'}), 'VXX:LNEI1=+00009');
        expect(cmd({'input': 'IIS:XXX'}), isNull);
        expect(cmd({'input': 'VXX:LNSI0=+00001'}), isNull);
        expect(cmd({'lensType': 'VXX:LNEI1=+00099'}), isNull);
        expect(cmd({'osd': true}), isNull);
      },
    );

    test('lens steps and home', () {
      final step = parseWebAction({
        'lens': 'shiftV',
        'dir': '+',
        'speed': 'fast',
      });
      expect(step?.command, 'VXX:LNSI3=+00200');
      expect(step?.isLensStep, isTrue);
      expect(
        cmd({'lens': 'zoom', 'dir': '-', 'speed': 'slow'}),
        'VXX:LNSI5=+00001',
      );
      final home = parseWebAction({'lens': 'home'});
      expect(home?.command, 'VXX:LNSI1=+00001');
      expect(home?.isLensStep, isFalse);
    });

    test('anything outside the vocabulary is refused', () {
      for (final bad in <Object?>[
        null,
        'PON',
        {'power': 'reboot'},
        {'power': 'on', 'shutter': 'open'},
        {'testPattern': 'OTS:99'},
        {'testPattern': 'VXX:RSTS1=+00001'},
        {'raw': 'VXX:RSTS1=+00001'},
        {'lens': 'shiftV', 'dir': 'up', 'speed': 'fast'},
        {'lens': 'shiftV', 'dir': '+', 'speed': 'warp'},
        {'lens': 'shiftV', 'dir': '+'},
        {'lens': 'iris', 'dir': '+', 'speed': 'fast'},
      ]) {
        expect(parseWebAction(bad), isNull, reason: '$bad');
      }
    });
  });

  group('parseWebActionRequest', () {
    const power = {'power': 'on'};

    test('targets: ids, a group, or all', () {
      final ids = parseWebActionRequest({
        'targets': ['a', 'b'],
        'action': power,
      });
      expect((ids!.targets as WebTargetIds).ids, ['a', 'b']);
      final group = parseWebActionRequest({
        'targets': {'group': 'g1'},
        'action': power,
      });
      expect((group!.targets as WebTargetGroup).groupId, 'g1');
      expect(
        parseWebActionRequest({'targets': 'all', 'action': power})!.targets,
        isA<WebTargetAll>(),
      );
    });

    test('bad targets or action → null', () {
      for (final bad in <Object?>[
        {'targets': <String>[], 'action': power},
        {
          'targets': [1],
          'action': power,
        },
        {'targets': 'some', 'action': power},
        {
          'targets': {'group': 1},
          'action': power,
        },
        {'targets': 'all'},
        {'action': power},
        'all',
      ]) {
        expect(parseWebActionRequest(bad), isNull, reason: '$bad');
      }
    });
  });
}
