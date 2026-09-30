import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_auth.dart';
import 'package:projector_grid/features/workspace/domain/web_pins.dart';

void main() {
  final viewerHash = hashPin('1111', random: Random(1));
  final operatorHash = hashPin('2222', random: Random(2));

  WebPinErrors check({
    String viewer = '',
    String operator = '',
    bool enabled = true,
    bool allowControl = true,
    String? vHash,
    String? oHash,
  }) => validateWebPins(
    viewerPin: viewer,
    operatorPin: operator,
    enabled: enabled,
    allowControl: allowControl,
    viewerHash: vHash,
    operatorHash: oHash,
  );

  test('nothing typed with both PINs stored is fine', () {
    expect(check(vHash: viewerHash, oHash: operatorHash), (
      viewer: null,
      operator: null,
    ));
  });

  test('4–8 digits', () {
    expect(
      check(viewer: '123', vHash: viewerHash, oHash: operatorHash).viewer,
      '4–8 digits',
    );
    expect(
      check(
        operator: '123456789',
        vHash: viewerHash,
        oHash: operatorHash,
      ).operator,
      '4–8 digits',
    );
  });

  test('a PIN is required once its role can be used', () {
    expect(check(oHash: operatorHash).viewer, 'Required');
    expect(check(enabled: false, allowControl: false).viewer, isNull);
    expect(check(vHash: viewerHash).operator, 'Required');
    expect(check(vHash: viewerHash, allowControl: false).operator, isNull);
  });

  test('the two PINs must differ, typed or stored', () {
    expect(
      check(viewer: '3333', operator: '3333').operator,
      'Same as Viewer PIN',
    );
    expect(
      check(operator: '1111', vHash: viewerHash).operator,
      'Same as Viewer PIN',
    );
    expect(
      check(viewer: '2222', vHash: viewerHash, oHash: operatorHash).viewer,
      'Same as Operator PIN',
    );
    expect(check(viewer: '3333', operator: '4444'), (
      viewer: null,
      operator: null,
    ));
  });
}
