import 'dart:async';
import 'package:panasonic_projectors_manager/core/services/panasonic_protocol_service.dart';

void main() async {
  final service = PanasonicProtocolService();
  print('Starting polling test...');
  final telemetry = await service.pollProjectorTelemetry('192.168.0.8', 1024, 'admin1', 'panasonic');
  print('Telemetry: $telemetry');
}
