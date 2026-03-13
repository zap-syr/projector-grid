import 'dart:async';
import 'package:panasonic_projectors_manager/core/services/panasonic_protocol_service.dart';

void main() async {
  final service = PanasonicProtocolService();
  print('Starting continuous polling test...');

  for (int i = 0; i < 4; i++) {
    print('\n[Poll ${i + 1}] Ping...');
    final telemetry = await service.pollProjectorTelemetry('192.168.0.8', 1024, 'admin1', 'panasonic');
    print('Telemetry: $telemetry');
    if (i < 3) {
      print('Waiting 60 seconds...');
      await Future.delayed(const Duration(seconds: 60));
    }
  }
}
