// Writes the two alert sounds to assets/sounds/:
//   alert_critical.wav — two quick rising tones, hard to miss
//   alert_warning.wav  — one soft tone
// Synthesised here so there is no licence to track. Run from the project
// root: dart run tool/generate_alert_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 44100;

/// One tone: [hz] for [ms], at [volume] 0–1, with short fades so it doesn't
/// click.
List<double> tone(double hz, int ms, {double volume = 0.5}) {
  final n = _rate * ms ~/ 1000;
  final fade = _rate * 12 ~/ 1000;
  return [
    for (var i = 0; i < n; i++)
      volume *
          sin(2 * pi * hz * i / _rate) *
          min(1, min(i / fade, (n - i) / fade)),
  ];
}

List<double> silence(int ms) => List.filled(_rate * ms ~/ 1000, 0);

void writeWav(String path, List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little) // fmt chunk size
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, _rate, Endian.little)
    ..setUint32(28, _rate * 2, Endian.little) // byte rate
    ..setUint16(32, 2, Endian.little) // block align
    ..setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i] * 32767).round(), Endian.little);
  }
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('wrote $path');
}

void main() {
  writeWav('assets/sounds/alert_critical.wav', [
    ...tone(880, 120),
    ...silence(60),
    ...tone(1175, 170),
  ]);
  writeWav('assets/sounds/alert_warning.wav', tone(660, 220, volume: 0.35));
}
