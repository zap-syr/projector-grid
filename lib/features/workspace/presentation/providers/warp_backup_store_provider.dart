import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/warp_backup_store.dart';

part 'warp_backup_store_provider.g.dart';

/// Where the backups of the free grid memories live. A provider so tests can
/// point it at a temp folder.
@Riverpod(keepAlive: true)
WarpBackupStore warpBackupStore(Ref ref) => WarpBackupStore.inConfigDir();
