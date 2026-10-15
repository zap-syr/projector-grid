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

/// The add button's label carries the count.
String addProjectorsLabel(int count) => switch (count) {
  1 => 'Add projector',
  0 => 'Add projectors',
  _ => 'Add $count projectors',
};
