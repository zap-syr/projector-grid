import 'package:flutter/material.dart';

import 'common/dialog_parts.dart';
import 'common/segmented_tabs.dart';
import 'control_bar/control_bar_parts.dart';
import 'control_bar/custom_tab.dart';
import 'control_bar/general_tab.dart';
import 'control_bar/system_tab.dart';

enum ControlBarTab { general, system, custom }

/// The 344 px panel right of the canvas: General / System / Custom tabs
/// whose commands go to the selected projectors. The cards live in
/// `control_bar/`, one file each.
class ControlBar extends StatefulWidget {
  const ControlBar({super.key});

  @override
  State<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<ControlBar> {
  ControlBarTab _tab = ControlBarTab.general;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ControlBarMetrics.width,
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).body,
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ControlBarMetrics.gutter,
              ControlBarMetrics.gutter,
              ControlBarMetrics.gutter,
              0,
            ),
            child: SegmentedTabs<ControlBarTab>(
              key: const ValueKey('control-bar-tabs'),
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
              tabs: [
                const SegmentedTab(
                  value: ControlBarTab.general,
                  label: 'General',
                ),
                const SegmentedTab(
                  value: ControlBarTab.system,
                  label: 'System',
                ),
                const SegmentedTab(
                  value: ControlBarTab.custom,
                  label: 'Custom',
                ),
              ],
            ),
          ),
          // Every tab stays built, so picks in its dropdowns, the open Lens
          // setup and the scroll position survive a tab switch.
          Expanded(
            child: IndexedStack(
              index: _tab.index,
              children: const [GeneralTab(), SystemTab(), CustomTab()],
            ),
          ),
        ],
      ),
    );
  }
}
