import 'package:flutter/material.dart';

import '../../domain/log_event.dart' show commandLabel;

/// Shows a SnackBar when a projector write command fails to send.
///
/// The Brightness Control, Color Correction, and Geometry Correction dialogs
/// each talk to the projector through their own `PanasonicProtocolService`
/// instance rather than workspace_provider's centralized dispatch (which logs
/// to the Event Log), so without this a failed send from one of those dialogs
/// would otherwise be entirely silent. Callers must confirm their `State` is
/// still `mounted` before passing [context].
void notifyCommandFailure(BuildContext context, String cmd) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to send: ${commandLabel(cmd)}')),
  );
}
