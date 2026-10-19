import 'dart:convert';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/app_config_dir.dart';
import '../../domain/monitoring_table_columns.dart';
import '../../domain/monitoring_view_settings.dart';

part 'monitoring_view_provider.g.dart';

/// The Monitoring view's layout ([MonitoringViewSettings]), saved to
/// `monitoring_view.json` on every change.
@Riverpod(keepAlive: true)
class MonitoringViewNotifier extends _$MonitoringViewNotifier {
  static String get _filePath => appConfigFilePath('monitoring_view.json');

  @override
  MonitoringViewSettings build() {
    try {
      final file = File(_filePath);
      if (!file.existsSync()) return const MonitoringViewSettings();
      return MonitoringViewSettings.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MonitoringViewSettings();
    }
  }

  void _set(MonitoringViewSettings next) {
    state = next;
    try {
      final file = File(_filePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(next.toJson()));
    } catch (_) {}
  }

  void setMode(MonitoringViewMode mode) => _set(state.copyWith(mode: mode));

  void setCardDensity(MonitoringCardDensity density) =>
      _set(state.copyWith(cardDensity: density));

  void setGroupByGroup(bool byGroup) =>
      _set(state.copyWith(groupByGroup: byGroup));

  void setColumns(List<String> columns) =>
      _set(state.copyWith(columns: List.unmodifiable(columns)));

  /// Shows or hides [id]; the last visible column can't be hidden.
  void toggleColumn(String id) {
    final next = toggleMonitoringTableColumn(state.columns, id);
    if (next != null) setColumns(next);
  }

  void setColumnWidth(String id, double width) => _set(
    state.copyWith(
      columnWidths: Map.unmodifiable({...state.columnWidths, id: width}),
    ),
  );

  /// Sorts by [columnId], or reverses the order when it already does.
  void sortBy(String columnId) => _set(
    state.copyWith(
      sortColumnId: columnId,
      sortAscending: state.sortColumnId == columnId
          ? !state.sortAscending
          : true,
    ),
  );

  void toggleCollapsed(String sectionKey) {
    final next = {...state.collapsed};
    if (!next.remove(sectionKey)) next.add(sectionKey);
    _set(state.copyWith(collapsed: Set.unmodifiable(next)));
  }

  void expand(String sectionKey) {
    if (state.collapsed.contains(sectionKey)) toggleCollapsed(sectionKey);
  }
}
