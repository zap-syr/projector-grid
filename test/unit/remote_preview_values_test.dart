import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/projector_web_status_service.dart';
import 'package:projector_grid/features/workspace/domain/pre_show.dart';
import 'package:projector_grid/features/workspace/domain/preview_signal_tag.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';

void main() {
  group('parsePreShowResponse', () {
    test('on, off, unreadable', () {
      expect(parsePreShowResponse('PSMI1=+00001'), isTrue);
      expect(parsePreShowResponse('PSMI1=+00000'), isFalse);
      expect(parsePreShowResponse('ER401'), isNull);
      expect(parsePreShowResponse(null), isNull);
    });
  });

  group('previewSignalTag', () {
    const n = ProjectorNode(
      id: '1',
      name: 'P',
      ipAddress: '10.0.0.1',
      x: 0,
      y: 0,
    );
    const web = WebSignalStatus(
      input: 'SDI1',
      signalName: '1080/50p',
      signalFrequency: '56.25kHz/50.00Hz',
    );

    test('the web status wins, input first', () {
      expect(
        previewSignalTag(n.copyWith(input: 'HDMI1'), web),
        'SDI1 · 1080/50p (56.25kHz/50.00Hz)',
      );
      expect(
        previewSignalTag(
          n,
          const WebSignalStatus(
            input: '',
            signalName: '---',
            signalFrequency: '',
          ),
        ),
        'No signal',
      );
    });

    test('polled values until the web status has been read', () {
      expect(
        previewSignalTag(n.copyWith(input: 'HDMI1', signal: '1080/60p'), null),
        'HDMI1 · 1080/60p',
      );
      expect(
        previewSignalTag(n.copyWith(signal: 'NO SIGNAL'), null),
        'No signal',
      );
      expect(previewSignalTag(n.copyWith(signal: '-'), null), isNull);
    });
  });
}
