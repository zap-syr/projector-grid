import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alignment.dart';
import 'package:projector_grid/features/workspace/domain/web_alignment.dart';

void main() {
  WebAlignmentOp? parse(
    String op, [
    Object? body,
    AlignmentPreset preset = AlignmentPreset.geometry,
  ]) => parseWebAlignmentOp(op, body, preset: preset);

  test('ops without arguments take no body', () {
    for (final c in WebAlignmentCommand.values) {
      expect((parse(c.name) as WebAlignmentSimple).command, c);
      expect(parse(c.name, {'x': 1}), isNull);
    }
  });

  test('enter: the page\'s selection, or none', () {
    expect((parse('enter') as WebAlignmentEnter).selection, isEmpty);
    expect(
      (parse('enter', {
        'targets': ['a', 'b'],
      }) as WebAlignmentEnter).selection,
      {'a', 'b'},
    );
    expect(parse('enter', {'targets': 'all'}), isNull);
    expect(
      parse('enter', {
        'targets': [1],
      }),
      isNull,
    );
  });

  test('focus and preset', () {
    expect((parse('focus', {'id': 'n2'}) as WebAlignmentFocus).id, 'n2');
    expect(parse('focus'), isNull);
    expect(
      (parse('preset', {'preset': 'color'}) as WebAlignmentPreset).preset,
      AlignmentPreset.color,
    );
    expect(parse('preset', {'preset': 'blend'}), isNull);
  });

  test('patterns must be ones the current preset offers', () {
    expect(
      (parse('focusedPattern', {
        'code': 'OTS:70',
      }) as WebAlignmentFocusedPattern).code,
      'OTS:70',
    );
    // White is a Color pattern, not a Geometry one…
    expect(parse('focusedPattern', {'code': 'OTS:01'}), isNull);
    // …but Custom offers every pattern.
    expect(
      parse('focusedPattern', {'code': 'OTS:01'}, AlignmentPreset.custom),
      isA<WebAlignmentFocusedPattern>(),
    );
    expect(parse('focusedPattern', {'code': 'VXX:RSTS1=1'}), isNull);
  });

  test('others: a pattern, or null for same as focused', () {
    expect(
      (parse('othersPattern', {
        'code': null,
      }) as WebAlignmentOthersPattern).code,
      isNull,
    );
    expect(
      (parse('othersPattern', {
        'code': 'OTS:71',
      }) as WebAlignmentOthersPattern).code,
      'OTS:71',
    );
    expect(parse('othersPattern'), isNull);
    expect(parse('othersPattern', {'code': 'OTS:01'}), isNull);
  });

  test('unknown ops and non-object bodies are refused', () {
    expect(parse('identify'), isNull);
    expect(parse('next', [1]), isNull);
    expect(parse('focus', 'n2'), isNull);
  });
}
