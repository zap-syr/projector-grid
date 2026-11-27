import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../features/workspace/domain/warp_codec.dart';
import 'app_config_dir.dart';
import 'app_log_file.dart';
import 'atomic_file.dart';

/// The raw table block read from a warp memory before the app first wrote to
/// it, kept so the memory can be put back exactly.
class WarpBackup {
  WarpBackup({
    required this.projectorKey,
    required this.modelId,
    required this.slot,
    required this.takenAt,
    required this.type,
    required this.method,
    required this.block,
    this.gridColumns,
    this.gridRows,
    this.storedAt,
  });

  /// Opaque to the store: the caller decides what identifies a projector.
  final String projectorKey;

  /// Parameter id of the model, such as `001c_00_26`.
  final String modelId;

  final WarpSlot slot;

  /// UTC.
  final DateTime takenAt;

  /// Table type code and method byte the block was read with.
  final int type;
  final int method;

  /// Control point counts read with the block.
  final int? gridColumns;
  final int? gridRows;

  /// The memory's last store time as read with the block, UTC.
  final DateTime? storedAt;

  /// The bytes exactly as read.
  final Uint8List block;
}

/// One JSON file per projector key and memory in [root].
class WarpBackupStore {
  WarpBackupStore(this.root);

  /// `<config dir>/warp_backups`.
  factory WarpBackupStore.inConfigDir() =>
      WarpBackupStore(Directory(appConfigFilePath('warp_backups')));

  final Directory root;

  static const _version = 1;

  Future<WarpBackup?> load(String projectorKey, WarpSlot slot) async {
    final file = _file(projectorKey, slot);
    if (!await file.exists()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      if (json['version'] != _version) {
        throw FormatException('unsupported version ${json['version']}');
      }
      // Two keys can sanitise to one file name; the file belongs to whoever
      // wrote it.
      if (json['projectorKey'] != projectorKey) return null;
      final stored = json['slot'] as String;
      if (stored != slot.name) {
        throw FormatException('file holds $stored, not ${slot.name}');
      }
      return WarpBackup(
        projectorKey: projectorKey,
        modelId: json['modelId'] as String,
        slot: slot,
        takenAt: DateTime.parse(json['takenAt'] as String).toUtc(),
        type: json['type'] as int,
        method: json['method'] as int,
        gridColumns: _optional<int>(json, 'gridColumns'),
        gridRows: _optional<int>(json, 'gridRows'),
        storedAt: _optional<String>(json, 'storedAt') == null
            ? null
            : DateTime.parse(json['storedAt'] as String).toUtc(),
        block: base64Decode(json['block'] as String),
      );
    } catch (e) {
      // The file stays: it may still be recoverable by hand, and it is the
      // only copy of what the memory held.
      AppLog.error('Warp backup load', '${file.path} is unusable ($e)', null);
      return null;
    }
  }

  /// Replaces an existing backup of the same key and memory.
  Future<void> save(WarpBackup backup) async {
    if (backup.slot == WarpSlot.ram) {
      throw ArgumentError.value(backup.slot, 'slot', 'RAM has no backup');
    }
    final json = <String, Object?>{
      'version': _version,
      'projectorKey': backup.projectorKey,
      'modelId': backup.modelId,
      'slot': backup.slot.name,
      'takenAt': backup.takenAt.toUtc().toIso8601String(),
      'type': backup.type,
      'method': backup.method,
      'gridColumns': backup.gridColumns,
      'gridRows': backup.gridRows,
      'storedAt': backup.storedAt?.toUtc().toIso8601String(),
      'block': base64Encode(backup.block),
    };
    await writeFileAtomic(
      _file(backup.projectorKey, backup.slot).path,
      jsonEncode(json),
    );
  }

  Future<void> delete(String projectorKey, WarpSlot slot) async {
    final file = _file(projectorKey, slot);
    if (await file.exists()) await file.delete();
  }

  /// A key that is present but null is fine; a key that is absent is not.
  static T? _optional<T>(Map<String, Object?> json, String key) {
    if (!json.containsKey(key)) throw FormatException('missing $key');
    return json[key] as T?;
  }

  File _file(String projectorKey, WarpSlot slot) {
    final safe = projectorKey.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9._-]'),
      '_',
    );
    return File(
      '${root.path}${Platform.pathSeparator}${safe}_${slot.name}.json',
    );
  }
}
