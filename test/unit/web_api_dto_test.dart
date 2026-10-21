import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';
import 'package:projector_grid/core/services/web_api.dart';
import 'package:projector_grid/core/services/web_auth.dart';
import 'package:projector_grid/core/theme/status_thresholds.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/alignment.dart';
import 'package:projector_grid/features/workspace/domain/dispatch_result.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_status.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/web_api_dto.dart';

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
  ProjectorNode(
    id: 'n4',
    name: 'PJ-04',
    ipAddress: '192.168.0.131',
    x: 160,
    y: 180,
    polled: true,
    lastSeen: DateTime.utc(2026, 10, 6, 14, 1),
  ),
];

/// n2 runs warm: its intake alert colours the value and makes it a problem.
final _alerts = [
  ActiveAlert(
    nodeId: 'n2',
    rule: AlertRule.intakeTemp,
    severity: AlertSeverity.warning,
    value: '41 °C',
    since: DateTime.utc(2026, 10, 6, 14, 2),
  ),
];

/// [projectorsJson] with each node's status as `monitoringStatusProvider`
/// computes it.
List<Json> _projectors(
  List<ProjectorNode> nodes, [
  List<ActiveAlert> alerts = const [],
]) => projectorsJson(nodes, {
  for (final n in nodes)
    n.id: monitoringStatusOf(
      n,
      alerts.where((a) => a.nodeId == n.id),
      const AlertSettings(),
    ),
});

void main() {
  group('fixtures (contract with openapi.yaml)', () {
    test('projectors, in layout order and without credentials', () {
      final json = _projectors(_nodes, _alerts);
      expect(json.map((p) => p['id']), ['n1', 'n2', 'n3', 'n4']);
      expect(jsonEncode(json), isNot(contains('secret')));
      expectFixture('projectors', json);
    });

    test('status: level, problems and the alert-coloured temperature', () {
      final byId = {for (final p in _projectors(_nodes, _alerts)) p['id']: p};
      Json status(String id) => byId[id]!['status']! as Json;
      expect(status('n2'), {
        'level': 'warning',
        'online': true,
        'standby': false,
        'intake': 'warning',
        'exhaust': null,
        'problems': [
          {
            'level': 'warning',
            'kind': 'temperature',
            'badge': 'Intake hot',
            'title': 'Intake temperature',
            'value': '41 °C, limit 40 °C',
            'flag': '41 °C',
            'since': '2026-10-06T14:02:00.000Z',
          },
        ],
      });
      expect(status('n1')['level'], 'error');
      expect(status('n3')['problems'], [containsPair('badge', 'Wrong login')]);
      expect(status('n4')['level'], 'offline');
      expect(byId['n4']!['lastSeen'], '2026-10-06T14:01:00.000Z');
      expect(byId['n2']!['lastSeen'], isNull);
    });

    test('an alert alone changes the status and sends the projector', () {
      final events = projectorEvents(
        _projectors(_nodes),
        _projectors(_nodes, _alerts),
      );
      expect(events.single.name, WebEvents.projector);
      expect((events.single.data! as Map)['id'], 'n2');
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
            widths: const {'projector': 180},
            sortColumn: 'projector',
            sortAscending: true,
            density: 'standard',
            fitToWidth: true,
            groupBy: false,
          ),
          intakeThreshold: kDefaultIntakeTempThreshold,
          exhaustThreshold: kDefaultExhaustTempThreshold,
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
          projectors: _projectors(_nodes),
          groups: groupsJson([_stage]),
        ),
      );
      expectFixture('event-project', {'name': 'Main Hall'});
    });

    test('alignment', () {
      expectFixture(
        'alignment',
        alignmentJson(
          active: true,
          busy: false,
          focusedId: 'n2',
          roles: const {
            'n1': AlignmentRole.shown,
            'n2': AlignmentRole.focused,
            'n4': AlignmentRole.closed,
          },
          preset: AlignmentPreset.geometry,
          focusedPattern: 'OTS:07',
          othersPattern: 'OTS:70',
          showNeighbours: true,
          includeDiagonals: false,
          showAll: false,
        ),
      );
      expectFixture(
        'alignment-off',
        alignmentJson(
          active: false,
          busy: false,
          focusedId: null,
          roles: const {},
          preset: AlignmentPreset.color,
          focusedPattern: 'OTS:01',
          othersPattern: null,
          showNeighbours: false,
          includeDiagonals: false,
          showAll: false,
        ),
      );
    });

    test('preview', () {
      expectFixture(
        'preview-status',
        previewStatusJson(
          preview: RemotePreviewFrame(
            Uint8List(0),
            overlay: RemotePreviewOverlay.testPattern,
          ),
          signal: 'HDMI1: 1080/60p (67.50 kHz, 60.00 Hz)',
          preShow: (on: true, applying: false),
        ),
      );
      expectFixture(
        'preview-status-notice',
        previewStatusJson(
          preview: const RemotePreviewNotice(RemotePreviewNoticeKind.noSignal),
          signal: null,
          preShow: (on: null, applying: true),
        ),
      );
      expectFixture('preview-frame', previewFrameJson([0xFF, 0xD8, 0xFF]));
    });

    test('alerts, in display order, times in UTC', () {
      final since = DateTime.utc(2026, 10, 6, 14, 2);
      final json = alertsJson(
        now: DateTime.utc(2026, 10, 6, 14, 20),
        alerts: [
          ActiveAlert(
            nodeId: 'n2',
            rule: AlertRule.intakeTemp,
            severity: AlertSeverity.warning,
            value: '43 °C',
            since: since,
            acknowledged: true,
          ),
          ActiveAlert(
            nodeId: 'n1',
            rule: AlertRule.signalLost,
            severity: AlertSeverity.critical,
            value: 'No signal on SDI 1',
            since: since,
            restoredAt: since.add(const Duration(seconds: 4)),
          ),
          ActiveAlert(
            nodeId: 'n1',
            rule: AlertRule.error,
            item: 'F011',
            severity: AlertSeverity.critical,
            value: 'Shutter error (F011)',
            since: since,
          ),
        ],
        nodes: {for (final n in _nodes) n.id: n},
      );
      final alerts = json['alerts']! as List;
      expect(alerts.map((a) => (a as Map)['id']), [
        'n1|error|F011',
        'n1|signal-lost|',
        'n2|intake-temp|',
      ]);
      expect((alerts[1] as Map)['value'], 'Back after 4 s');
      expectFixture('alerts', json);
    });

    test('dispatch result', () {
      expectFixture(
        'dispatch-result',
        dispatchResultJson(
          DispatchResult(
            command: 'OSH:1',
            ok: 2,
            failed: [_nodes[2]],
            skipped: [_nodes[3]],
          ),
        ),
      );
    });
  });

  group('projectorEvents', () {
    final before = _projectors(_nodes);

    test('nothing changed → no events', () {
      expect(projectorEvents(before, _projectors(_nodes)), isEmpty);
    });

    test('a telemetry change sends only that projector', () {
      final next = [..._nodes];
      next[0] = next[0].copyWith(intakeTemp: '42°C');
      final events = projectorEvents(before, _projectors(next));
      expect(events, hasLength(1));
      expect(events.single.name, WebEvents.projector);
      expect((events.single.data! as Map)['intakeTemp'], '42°C');
    });

    test('credential-only changes send nothing', () {
      final next = [..._nodes];
      next[0] = next[0].copyWith(password: 'changed');
      expect(projectorEvents(before, _projectors(next)), isEmpty);
    });

    test('added, removed or reordered → the whole list', () {
      for (final next in [
        _nodes.sublist(1),
        [..._nodes, _nodes[0].copyWith(id: 'n5', x: 300)],
        // PJ-02 dragged below the second row.
        [_nodes[0].copyWith(y: 400), ..._nodes.sublist(1)],
      ]) {
        final events = projectorEvents(before, _projectors(next));
        expect(events.single.name, WebEvents.projectors);
      }
    });
  });

  test('errorItems decode the codes; an unchanged list sends nothing', () {
    final node = _nodes[0].copyWith(errors: 'F011 F204');
    expect(_projectors([node]).single['errorItems'], [
      {'code': 'F011', 'name': 'Shutter error', 'severity': 'critical'},
      {'code': 'F204', 'name': 'Fan warning', 'severity': 'warning'},
    ]);
    final before = _projectors([node]);
    expect(projectorEvents(before, _projectors([node])), isEmpty);
    expect(
      projectorEvents(before, _projectors([node.copyWith(errors: 'F011')])),
      hasLength(1),
    );
  });

  group('parseAlertAcknowledge', () {
    final since = DateTime.utc(2026);
    final a = ActiveAlert(
      nodeId: 'n1',
      rule: AlertRule.offline,
      severity: AlertSeverity.critical,
      value: 'No answer',
      since: since,
    );
    final b = ActiveAlert(
      nodeId: 'n2',
      rule: AlertRule.error,
      item: 'F011',
      severity: AlertSeverity.critical,
      value: 'Shutter error (F011)',
      since: since,
    );
    List<String> picks(Object? body) => [
      for (final x in [a, b])
        if (parseAlertAcknowledge(body)!(x)) x.nodeId,
    ];

    test('ids, projector, rule or all', () {
      expect(
        picks({
          'ids': ['n2|error|F011'],
        }),
        ['n2'],
      );
      expect(picks({'projectorId': 'n1'}), ['n1']);
      expect(picks({'rule': 'error'}), ['n2']);
      expect(picks({'all': true}), ['n1', 'n2']);
    });

    test('anything else is refused', () {
      for (final body in [
        null,
        'all',
        <String, Object?>{},
        {'all': false},
        {'ids': <Object?>[]},
        {
          'ids': [1],
        },
        {'rule': 'nope'},
        {'all': true, 'rule': 'offline'},
      ]) {
        expect(parseAlertAcknowledge(body), isNull, reason: '$body');
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
}
