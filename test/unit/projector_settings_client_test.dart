import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/projector_settings_client.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';

void main() {
  late FakeProtocolService fake;
  late List<String> failures;
  late ProjectorSettingsClient client;

  setUp(() {
    fake = FakeProtocolService();
    failures = [];
    client = ProjectorSettingsClient(
      service: fake,
      node: node('1'),
      onFailure: failures.add,
    );
  });

  test('reads keyed values from QVX replies', () async {
    fake.rawResponses.addAll({
      'QVX:GMKI4': 'GMKI4=-00012',
      'QVX:GMKS8': 'GMKS8=+12.4',
    });
    expect(await client.readInt('GMKI4'), -12);
    expect(await client.readDouble('GMKS8'), 12.4);
    expect(await client.readInt('GMKI7'), isNull);
  });

  test('writes are formatted and failures reported', () async {
    expect(await client.writeInt('GMKI4', 5), isTrue);
    await client.writeDeg('GMKS8', -3);
    await client.writeThrow('GMKS0', 1.5);
    await client.writeBool('GMCIA', true);
    expect(fake.sentRaw.map((s) => s.$2), [
      'VXX:GMKI4=+00005',
      'VXX:GMKS8=-3.0',
      'VXX:GMKS0=+01.5',
      'VXX:GMCIA=+00001',
    ]);
    expect(failures, isEmpty);

    fake.rawResponses['VXX:GMKI4=+00001'] = null;
    expect(await client.writeInt('GMKI4', 1), isFalse);
    expect(failures, ['VXX:GMKI4=+00001']);
  });

  test('queryAll keeps order across batches', () async {
    final cmds = [for (var i = 0; i < 11; i++) 'Q$i'];
    for (final c in cmds) {
      fake.rawResponses[c] = 'r$c';
    }
    final results = await client.queryAll(cmds, maxConcurrent: 4);
    expect(results, [for (final c in cmds) 'r$c']);
  });
}
