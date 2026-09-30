import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_api.dart';
import 'package:projector_grid/core/services/web_auth.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_columns.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/web_api_dto.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/monitoring_table.dart';

/// Compares [json] with `test/fixtures/api/<name>.json`, which the web tests
/// validate against `web_ui/api/openapi.yaml`. Regenerate with
/// `flutter test --update-goldens test/unit/web_api_dto_test.dart`.
void expectFixture(String name, Object? json) {
  final file = File('test/fixtures/api/$name.json');
  final text = '${const JsonEncoder.withIndent('  ').convert(json)}\n';
  if (autoUpdateGoldenFiles) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: '${file.path} missing — run with --update-goldens',
  );
  expect(file.readAsStringSync().replaceAll('\r\n', '\n'), text);
}

const _stage = ProjectorGroup(id: 'g1', name: 'Stage', color: 0xFFE8710A);
const _balcony = ProjectorGroup(id: 'g2', name: 'Balcony', color: 0xFF9334E6);

final _nodes = [
  const ProjectorNode(
    id: 'n2',
    name: 'PJ-02',
    ipAddress: '192.168.0.112',
    login: 'admin1',
    password: 'secret',
    x: 160,
    y: 40,
    connectionStatus: ConnectionStatus.connected,
    powerStatus: PowerStatus.on,
    shutterStatus: ShutterStatus.open,
    serialNumber: 'SH4213002',
    runtime: '8398H',
    lightRuntime: '1518H',
    intakeTemp: '41°C',
    exhaustTemp: '47°C',
    acVoltage: '230V',
    errors: 'NO ERRORS',
    input: 'SDI1',
    signal: '1080/60p',
    testPattern: 'OTS:07',
    groupId: 'g1',
  ),
  const ProjectorNode(
    id: 'n1',
    name: 'PJ-01',
    ipAddress: '192.168.0.111',
    x: 20,
    y: 40,
    connectionStatus: ConnectionStatus.unprotected,
    powerStatus: PowerStatus.cooling,
    serialNumber: 'SH4213001',
    errors: '000100000000',
    testPattern: 'OTS:00',
    groupId: 'g1',
  ),
  const ProjectorNode(
    id: 'n3',
    name: 'PJ-03',
    ipAddress: '192.168.0.121',
    x: 20,
    y: 180,
    connectionStatus: ConnectionStatus.unauthorized,
    groupId: 'g2',
  ),
  const ProjectorNode(
    id: 'n4',
    name: 'PJ-04',
    ipAddress: '192.168.0.131',
    x: 160,
    y: 180,
  ),
];

void main() {
  group('fixtures (contract with openapi.yaml)', () {
    test('projectors, in layout order and without credentials', () {
      final json = projectorsJson(_nodes);
      expect(json.map((p) => p['id']), ['n1', 'n2', 'n3', 'n4']);
      expect(jsonEncode(json), isNot(contains('secret')));
      expectFixture('projectors', json);
    });

    test('groups', () {
      expectFixture('groups', groupsJson([_stage, _balcony]));
    });

    test('config', () {
      expectFixture(
        'config',
        configJson(
          projectName: 'Main Hall',
          role: WebRole.viewer,
          layout: (
            columns: const [],
            widths: const {'model': 180},
            sortColumn: 'ip',
            sortAscending: true,
            density: 'standard',
            fitToWidth: true,
            groupBy: false,
          ),
        ),
      );
    });

    test('session, login and errors', () {
      expectFixture(
        'session-signed-out',
        sessionJson(projectName: 'Main Hall', controlAllowed: false),
      );
      expectFixture(
        'session-signed-in',
        sessionJson(
          projectName: 'Main Hall',
          controlAllowed: true,
          role: WebRole.viewer,
        ),
      );
      expectFixture(
        'login',
        loginJson(
          WebSession('tok', WebRole.operator, '10.0.0.5', DateTime(0)),
          controlAllowed: true,
        ),
      );
      expectFixture(
        'access',
        accessJson(WebRole.operator, controlAllowed: true),
      );
      expectFixture('error', errorJson('invalid_pin'));
      expectFixture(
        'error-locked-out',
        errorJson('locked_out', retryAfter: 60),
      );
    });

    test('events', () {
      expectFixture(
        'event-snapshot',
        snapshotJson(
          projectName: 'Main Hall',
          projectors: projectorsJson(_nodes),
          groups: groupsJson([_stage]),
        ),
      );
      expectFixture('event-project', {'name': 'Main Hall'});
    });
  });

  group('projectorEvents', () {
    final before = projectorsJson(_nodes);

    test('nothing changed → no events', () {
      expect(projectorEvents(before, projectorsJson(_nodes)), isEmpty);
    });

    test('a telemetry change sends only that projector', () {
      final next = [..._nodes];
      next[0] = next[0].copyWith(intakeTemp: '42°C');
      final events = projectorEvents(before, projectorsJson(next));
      expect(events, hasLength(1));
      expect(events.single.name, WebEvents.projector);
      expect((events.single.data! as Map)['intakeTemp'], '42°C');
    });

    test('credential-only changes send nothing', () {
      final next = [..._nodes];
      next[0] = next[0].copyWith(password: 'changed');
      expect(projectorEvents(before, projectorsJson(next)), isEmpty);
    });

    test('added, removed or reordered → the whole list', () {
      for (final next in [
        _nodes.sublist(1),
        [..._nodes, _nodes[0].copyWith(id: 'n5', x: 300)],
        // PJ-02 dragged below the second row.
        [_nodes[0].copyWith(y: 400), ..._nodes.sublist(1)],
      ]) {
        final events = projectorEvents(before, projectorsJson(next));
        expect(events.single.name, WebEvents.projectors);
      }
    });
  });

  test('sameGroupsJson', () {
    final a = groupsJson([_stage, _balcony]);
    expect(sameGroupsJson(a, groupsJson([_stage, _balcony])), isTrue);
    expect(sameGroupsJson(a, groupsJson([_stage])), isFalse);
    expect(
      sameGroupsJson(a, groupsJson([_stage.copyWith(name: 'Main'), _balcony])),
      isFalse,
    );
  });

  test('webProjectName', () {
    expect(webProjectName(null), 'New Project');
    expect(webProjectName(r'C:\Shows\Main Hall.pgrid'), 'Main Hall');
    expect(webProjectName('/Users/a/Main Hall.PGRID'), 'Main Hall');
  });

  test('group colour is #RRGGBB without alpha', () {
    expect(groupJson(_stage)['color'], '#E8710A');
    expect(
      groupJson(
        const ProjectorGroup(id: 'x', name: 'x', color: 0xFF00000A),
      )['color'],
      '#00000A',
    );
  });

  test('the table renders the shared column catalogue in its order', () {
    expect(MonitoringTable.allColumnIds, [
      for (final c in kMonitoringColumns) c.id,
    ]);
    for (final c in kMonitoringColumns) {
      expect(MonitoringTable.labelFor(c.id), c.label);
    }
  });
}
