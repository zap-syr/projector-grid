import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/signal_state.dart';

ProjectorNode _node({
  String signal = '-',
  PowerStatus power = PowerStatus.on,
  ConnectionStatus status = ConnectionStatus.connected,
}) => ProjectorNode(
  id: '1',
  name: 'PT-RQ35K',
  ipAddress: '10.0.0.1',
  x: 0,
  y: 0,
  signal: signal,
  powerStatus: power,
  connectionStatus: status,
);

void main() {
  test('a real signal is green with its resolution', () {
    expect(signalStateOf(_node(signal: '1080/60p')), (
      label: '1080/60p',
      tone: SignalTone.good,
    ));
  });

  test('no signal is red only while the projector is on', () {
    expect(signalStateOf(_node(signal: 'NO SIGNAL')).tone, SignalTone.missing);
    for (final power in [
      PowerStatus.standby,
      PowerStatus.turningOn,
      PowerStatus.cooling,
    ]) {
      expect(signalStateOf(_node(signal: 'NO SIGNAL', power: power)), (
        label: 'No signal',
        tone: SignalTone.unknown,
      ), reason: power.name);
    }
  });

  test('unknown when offline, on a failed login or before a reading', () {
    for (final status in [
      ConnectionStatus.offline,
      ConnectionStatus.unauthorized,
    ]) {
      expect(signalStateOf(_node(signal: '1080/60p', status: status)), (
        label: 'Unknown',
        tone: SignalTone.unknown,
      ), reason: status.name);
    }
    for (final raw in ['-', 'ER401', 'Timeout', '']) {
      expect(signalStateOf(_node(signal: raw)).tone, SignalTone.unknown);
    }
  });

  test('a projector without a password reads like a connected one', () {
    expect(
      signalStateOf(
        _node(signal: '1080/60p', status: ConnectionStatus.unprotected),
      ).tone,
      SignalTone.good,
    );
  });
}
