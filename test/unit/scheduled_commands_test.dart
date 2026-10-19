import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/custom_command.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_commands.dart';

void main() {
  final catalog = scheduledCommandCatalog(const [
    CustomCommand(id: 'c1', name: 'Dynamic contrast', command: 'VXX:DCNI0=1'),
    CustomCommand(id: 'c2', name: 'Lamp eco', command: 'OLP:1'),
  ]);
  List<String> labels(Iterable<ScheduledCommand> list) => [
    for (final c in list) c.label,
  ];

  test('the catalog: the built-in table, then the custom commands', () {
    expect(catalog, hasLength(17));
    expect(
      catalog.where((c) => c.category == CommandCategory.power),
      hasLength(2),
    );
    expect(
      catalog.where((c) => c.category == CommandCategory.shutter),
      hasLength(2),
    );
    expect(
      catalog.where((c) => c.category == CommandCategory.input),
      hasLength(11),
    );
    expect(labels(catalog.skip(15)), ['Dynamic contrast', 'Lamp eco']);
  });

  group('search', () {
    test('an empty query keeps everything in catalog order', () {
      expect(searchScheduledCommands(catalog, '  '), catalog);
    });

    test('matches names, ignoring case', () {
      expect(labels(searchScheduledCommands(catalog, 'hdmi')), [
        'HDMI 1',
        'HDMI 2',
      ]);
      expect(labels(searchScheduledCommands(catalog, 'LAMP')), ['Lamp eco']);
    });

    test('every word must match', () {
      expect(labels(searchScheduledCommands(catalog, 'hdmi 2')), ['HDMI 2']);
      expect(labels(searchScheduledCommands(catalog, 'power close')), isEmpty);
    });

    test('a category name finds its commands', () {
      expect(labels(searchScheduledCommands(catalog, 'shutter')), [
        'Shutter open',
        'Shutter close',
      ]);
      expect(searchScheduledCommands(catalog, 'input'), hasLength(11));
    });

    test('never matches the command strings', () {
      expect(searchScheduledCommands(catalog, 'OSH'), isEmpty);
      expect(searchScheduledCommands(catalog, 'IIS'), isEmpty);
    });

    test('limited to a category', () {
      expect(
        labels(
          searchScheduledCommands(
            catalog,
            'on',
            category: CommandCategory.power,
          ),
        ),
        ['Power on'],
      );
      expect(
        labels(
          searchScheduledCommands(
            catalog,
            '',
            category: CommandCategory.custom,
          ),
        ),
        ['Dynamic contrast', 'Lamp eco'],
      );
    });

    test('no match gives an empty list', () {
      expect(searchScheduledCommands(catalog, 'zzz'), isEmpty);
    });
  });

  group('a saved task back to its catalog entry', () {
    test('a built-in command, whatever label an older file saved', () {
      final c = scheduledCommandFor(catalog, 'PON', 'Power On');
      expect(c?.label, 'Power on');
      expect(c?.category, CommandCategory.power);
    });

    test('a custom command, even renamed since', () {
      expect(
        scheduledCommandFor(catalog, 'OLP:1', 'Old name')?.label,
        'Lamp eco',
      );
    });

    test('a typed command string is not in the catalog', () {
      expect(scheduledCommandFor(catalog, 'VXX:LPMI1=1', 'Lamp mode'), isNull);
    });

    test('built-in labels replace the saved ones', () {
      expect(scheduledCommandLabel('POF', 'Power Standby'), 'Power standby');
      expect(scheduledCommandLabel('OLP:1', 'Lamp eco'), 'Lamp eco');
    });
  });
}
