/// How the Monitoring view is laid out (§7i of the redesign plan): Table or
/// Cards, the cards' density, Group by, the table's columns and sort, and
/// the collapsed groups. Remembered between sessions in its own file, apart
/// from `AppSettings`, whose `monitoring*` fields are the Web UI's starting
/// layout and use the Web UI's column ids.
library;

enum MonitoringViewMode { table, cards }

enum MonitoringCardDensity { compact, extended }

/// The key of the Ungrouped section in [MonitoringViewSettings.collapsed].
const String kUngroupedSectionKey = '';

class MonitoringViewSettings {
  final MonitoringViewMode mode;
  final MonitoringCardDensity cardDensity;

  /// Group by group (true, the default) or none: one flat list with a Group
  /// column.
  final bool groupByGroup;

  /// Visible table columns in order; empty means the default set.
  final List<String> columns;
  final Map<String, double> columnWidths;
  final String sortColumnId;
  final bool sortAscending;

  /// Collapsed group sections by group id, [kUngroupedSectionKey] for
  /// Ungrouped.
  final Set<String> collapsed;

  const MonitoringViewSettings({
    this.mode = MonitoringViewMode.table,
    this.cardDensity = MonitoringCardDensity.extended,
    this.groupByGroup = true,
    this.columns = const [],
    this.columnWidths = const {},
    this.sortColumnId = 'projector',
    this.sortAscending = true,
    this.collapsed = const {},
  });

  MonitoringViewSettings copyWith({
    MonitoringViewMode? mode,
    MonitoringCardDensity? cardDensity,
    bool? groupByGroup,
    List<String>? columns,
    Map<String, double>? columnWidths,
    String? sortColumnId,
    bool? sortAscending,
    Set<String>? collapsed,
  }) => MonitoringViewSettings(
    mode: mode ?? this.mode,
    cardDensity: cardDensity ?? this.cardDensity,
    groupByGroup: groupByGroup ?? this.groupByGroup,
    columns: columns ?? this.columns,
    columnWidths: columnWidths ?? this.columnWidths,
    sortColumnId: sortColumnId ?? this.sortColumnId,
    sortAscending: sortAscending ?? this.sortAscending,
    collapsed: collapsed ?? this.collapsed,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'cardDensity': cardDensity.name,
    'groupByGroup': groupByGroup,
    'columns': columns,
    'columnWidths': columnWidths,
    'sortColumnId': sortColumnId,
    'sortAscending': sortAscending,
    'collapsed': collapsed.toList(),
  };

  factory MonitoringViewSettings.fromJson(Map<String, dynamic> json) =>
      MonitoringViewSettings(
        mode: MonitoringViewMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => MonitoringViewMode.table,
        ),
        cardDensity: MonitoringCardDensity.values.firstWhere(
          (d) => d.name == json['cardDensity'],
          orElse: () => MonitoringCardDensity.extended,
        ),
        groupByGroup: (json['groupByGroup'] as bool?) ?? true,
        columns: (json['columns'] as List?)?.cast<String>() ?? const [],
        columnWidths:
            (json['columnWidths'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            const {},
        sortColumnId: (json['sortColumnId'] as String?) ?? 'projector',
        sortAscending: (json['sortAscending'] as bool?) ?? true,
        collapsed: {...?(json['collapsed'] as List?)?.cast<String>()},
      );
}
