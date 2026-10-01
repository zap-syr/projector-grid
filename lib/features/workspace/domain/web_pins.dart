/// Web Access PIN rules for the Preferences dialog: 4–8 digits, a PIN is
/// required once its role can be used, and the two PINs must differ (the
/// server tells the role from which PIN matches).
library;

import '../../../core/services/web_auth.dart';

typedef WebPinErrors = ({String? viewer, String? operator});

/// [viewerPin] / [operatorPin] are what's typed (empty = keep the stored
/// one); [viewerHash] / [operatorHash] are the stored PINs.
WebPinErrors validateWebPins({
  required String viewerPin,
  required String operatorPin,
  required bool enabled,
  required bool allowControl,
  required String? viewerHash,
  required String? operatorHash,
}) {
  String? lengthError(String pin) =>
      pin.isNotEmpty && (pin.length < 4 || pin.length > 8)
      ? '4–8 digits'
      : null;

  var viewer =
      lengthError(viewerPin) ??
      (enabled && viewerPin.isEmpty && viewerHash == null ? 'Required' : null);
  var operator =
      lengthError(operatorPin) ??
      (allowControl && operatorPin.isEmpty && operatorHash == null
          ? 'Required'
          : null);
  if (viewer != null || operator != null) {
    return (viewer: viewer, operator: operator);
  }

  if (operatorPin.isNotEmpty) {
    final same = viewerPin.isNotEmpty
        ? viewerPin == operatorPin
        : viewerHash != null && verifyPin(operatorPin, viewerHash);
    if (same) operator = 'Same as Viewer PIN';
  } else if (viewerPin.isNotEmpty && operatorHash != null) {
    if (verifyPin(viewerPin, operatorHash)) viewer = 'Same as Operator PIN';
  }
  return (viewer: viewer, operator: operator);
}
