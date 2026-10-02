/// JSON shapes of the Web UI API's data (session/login/error shapes live in
/// `web_api.dart`). `web_ui/api/openapi.yaml` is the contract;
/// `test/unit/web_api_dto_test.dart` writes these into golden fixtures that
/// the web tests validate against it, so a field renamed on one side only
/// fails CI.
library;

import 'dart:convert';

import '../../../core/services/remote_preview_service.dart';
import '../../../core/services/web_api.dart' show Json;
import '../../../core/services/web_auth.dart';
import '../../../core/services/web_event_hub.dart';
import '../../../core/theme/status_thresholds.dart';
import 'alignment.dart';
import 'card_layout.dart';
import 'control_options.dart';
import 'dispatch_result.dart';
import 'log_event.dart';
import 'monitoring_columns.dart';
import 'pre_show.dart';
import 'projector_group.dart';
import 'projector_node.dart';
import 'test_patterns.dart';

/// SSE event names (`/api/events`).
abstract final class WebEvents {
  static const snapshot = 'snapshot';
  static const projectors = 'projectors';
  static const projector = 'projector';
  static const groups = 'groups';
  static const project = 'project';
  static const alignment = 'alignment';
  static const signedOut = 'signedOut';
}

/// The Monitoring layout the app currently uses; seeds a browser's table on
/// its first visit.
typedef WebTableLayout = ({
  List<String> columns,
  Map<String, double> widths,
  String sortColumn,
  bool sortAscending,
  String density,
  bool fitToWidth,
  bool groupBy,
});

/// Project file name without folder or `.pgrid`; "New Project" when unsaved,
/// like the window title.
String webProjectName(String? filePath) {
  if (filePath == null) return 'New Project';
  final name = filePath.split(RegExp(r'[/\\]')).last;
  return name.toLowerCase().endsWith('.pgrid')
      ? name.substring(0, name.length - '.pgrid'.length)
      : name;
}

/// Everything the page shows; never the NTCONTROL login or password.
Json projectorJson(ProjectorNode n) => {
  'id': n.id,
  'name': n.name,
  'ip': n.ipAddress,
  'groupId': n.groupId,
  'x': n.x,
  'y': n.y,
  'connection': n.connectionStatus.name,
  'power': n.powerStatus.name,
  'shutter': n.shutterStatus.name,
  'serial': n.serialNumber,
  'input': n.input,
  'signal': n.signal,
  'testPattern': n.testPattern,
  'runtime': n.runtime,
  'lightRuntime': n.lightRuntime,
  'intakeTemp': n.intakeTemp,
  'exhaustTemp': n.exhaustTemp,
  'acVoltage': n.acVoltage,
  'errors': n.errors,
};

/// All projectors in layout order (left→right, top→bottom).
List<Json> projectorsJson(Iterable<ProjectorNode> nodes) =>
    layoutOrder(nodes).map(projectorJson).toList();

Json groupJson(ProjectorGroup g) => {
  'id': g.id,
  'name': g.name,
  'color':
      '#${(g.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
};

List<Json> groupsJson(Iterable<ProjectorGroup> groups) =>
    groups.map(groupJson).toList();

Json configJson({
  required String projectName,
  required WebRole role,
  required WebTableLayout layout,
  required TempThreshold intakeThreshold,
  required TempThreshold exhaustThreshold,
}) => {
  'projectName': projectName,
  'role': role.name,
  'columns': [
    for (final c in kMonitoringColumns)
      {'id': c.id, 'label': c.label, 'defaultWidth': c.defaultWidth},
  ],
  'defaultColumns': kMonitoringDefaultColumns,
  'presets': [
    for (final e in kMonitoringPresets.entries)
      {'name': e.key, 'columns': e.value},
    {
      'name': 'Show all',
      'columns': [for (final c in kMonitoringColumns) c.id],
    },
  ],
  'minColumnWidth': kMonitoringMinColumnWidth,
  'layout': {
    'columns': resolveMonitoringColumns(layout.columns),
    'widths': layout.widths,
    'sortColumn': layout.sortColumn,
    'sortAscending': layout.sortAscending,
    'density': layout.density,
    'fitToWidth': layout.fitToWidth,
    'groupBy': layout.groupBy,
  },
  'thresholds': {
    'intake': {'warm': intakeThreshold.warm, 'hot': intakeThreshold.hot},
    'exhaust': {'warm': exhaustThreshold.warm, 'hot': exhaustThreshold.hot},
  },
  'testPatterns': _options(kTestPatternLabels),
  'inputs': _options(kInputOptions),
  'lensCalibrations': _options(kLensCalibrationOptions),
  'lensTypes': _options(kLensTypeOptions),
  'alignmentPresets': [
    for (final p in AlignmentPreset.values)
      {'id': p.name, 'label': p.label, 'patterns': p.patterns},
  ],
};

/// Alignment mode as the banner sees it. `roles` covers the mode's scope,
/// in no particular order — the page orders it by the projectors' layout
/// order.
Json alignmentJson({
  required bool active,
  required bool busy,
  required String? focusedId,
  required Map<String, AlignmentRole> roles,
  required AlignmentPreset preset,
  required String focusedPattern,
  required String? othersPattern,
  required bool showNeighbours,
  required bool includeDiagonals,
  required bool showAll,
}) => {
  'active': active,
  'busy': busy,
  'focusedId': focusedId,
  'roles': {for (final e in roles.entries) e.key: e.value.name},
  'preset': preset.name,
  'focusedPattern': focusedPattern,
  'othersPattern': othersPattern,
  'showNeighbours': showNeighbours,
  'includeDiagonals': includeDiagonals,
  'showAll': showAll,
};

/// SSE event names on `/api/preview/{id}`.
abstract final class WebPreviewEvents {
  static const status = 'status';
  static const frame = 'frame';
}

/// What a page's preview window shows besides the image: the feed's state,
/// its overlays and the projector's pre-show. Sent whenever it changes; a
/// `frame` event carries each new image while [preview] is live.
Json previewStatusJson({
  required RemotePreviewState preview,
  required String? signal,
  required PreShowState preShow,
}) => {
  'state': switch (preview) {
    RemotePreviewConnecting() => 'connecting',
    RemotePreviewFrame() => 'live',
    RemotePreviewNotice() => 'notice',
    RemotePreviewUnavailable() => 'unavailable',
  },
  'notice': preview is RemotePreviewNotice ? preview.kind.name : null,
  'overlay': preview is RemotePreviewFrame ? preview.overlay?.name : null,
  'signal': signal,
  'preShow': preShow.on,
  'preShowApplying': preShow.applying,
};

/// One JPEG of the preview feed.
Json previewFrameJson(List<int> jpeg) => {'jpeg': base64Encode(jpeg)};

/// [previewStatusJson] is flat, like the projector JSON.
bool samePreviewStatusJson(Json? a, Json b) => a != null && _sameJson(a, b);

List<Json> _options(Map<String, String> byCode) => [
  for (final e in byCode.entries) {'code': e.key, 'label': e.value},
];

/// The reply to `POST /api/actions` — the §10 summary, with the Event Log's
/// one-line text for the page's toast.
Json dispatchResultJson(DispatchResult r) {
  Json ref(ProjectorNode n) => {'id': n.id, 'name': n.name};
  return {
    'command': r.command,
    'label': commandLabel(r.command),
    'ok': r.ok,
    'total': r.total,
    'failed': r.failed.map(ref).toList(),
    'skipped': r.skipped.map(ref).toList(),
    'summary': dispatchSummary(r),
  };
}

/// The first event on `/api/events`.
Json snapshotJson({
  required String projectName,
  required List<Json> projectors,
  required List<Json> groups,
}) => {'projectName': projectName, 'projectors': projectors, 'groups': groups};

/// Events that bring a page from [prev] to [next]: the whole list when
/// projectors were added, removed or reordered, otherwise one `projector`
/// event per changed projector — a telemetry tick sends only what changed.
List<WebEvent> projectorEvents(List<Json> prev, List<Json> next) {
  final sameOrder =
      prev.length == next.length &&
      Iterable.generate(prev.length)
          .every((i) => prev[i]['id'] == next[i]['id']);
  if (!sameOrder) return [(name: WebEvents.projectors, data: next)];
  return [
    for (var i = 0; i < next.length; i++)
      if (!_sameJson(prev[i], next[i]))
        (name: WebEvents.projector, data: next[i]),
  ];
}

/// Flat maps of primitives, which is all [projectorJson] and [groupJson]
/// produce.
bool _sameJson(Json a, Json b) =>
    a.length == b.length && a.keys.every((k) => a[k] == b[k]);

bool sameGroupsJson(List<Json> a, List<Json> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((i) => _sameJson(a[i], b[i]));
