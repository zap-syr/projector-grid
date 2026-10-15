import 'package:flutter/widgets.dart';

/// The projector login every Add Projectors tab shows and sends, owned by
/// the dialog so switching tabs keeps it.
class AddLogin {
  const AddLogin({
    required this.login,
    required this.password,
    required this.lastUsed,
  });

  final TextEditingController login;
  final TextEditingController password;

  /// The fields still hold the login saved from the last add.
  final bool lastUsed;

  /// One entry for `WorkspaceNotifier.addProjectors`.
  Map<String, dynamic> config(
    String ip,
    int port, {
    String? name,
    String status = 'offline',
  }) => {
    'ip': ip,
    'name': ?name,
    'port': port,
    'login': login.text,
    'password': password.text,
    'status': status,
  };
}

typedef AddProjectorsCallback = void Function(
  List<Map<String, dynamic>> projectors,
);

// The field row at the top of each tab (Address, IP range, Discover) uses
// the same padding, gap and Port width, so the fields don't move when the
// tab changes.
// The bottom padding is also the gap between the last card (range
// preview, Discover results) and the footer, the same on every tab.
const addTabPadding = EdgeInsets.fromLTRB(24, 20, 24, 20);
const addTabFieldGap = 12.0;
const addTabPortWidth = 110.0;

/// Between the field row and the Projector login card, which sits right
/// under the fields on every tab so it doesn't move either. The row
/// already ends in the line reserved for a field's error, hence small.
const addTabLoginGap = 8.0;

/// Between the login card and the card under it (range preview, Discover
/// results).
const addTabSectionGap = 16.0;

// The add button: one projector on Address, several on the other tabs,
// always as wide as the longer label so Cancel never moves.
const addOneLabel = 'Add projector';
const addManyLabel = 'Add projectors';
