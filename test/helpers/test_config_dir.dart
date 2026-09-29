import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_config_dir.dart';

/// Points the app's config directory at a fresh temp dir for each test in the
/// enclosing group, so no test touches the real user's settings files.
/// Returns a getter for the current test's directory.
Directory Function() useTempConfigDir() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('pgrid_test_');
    debugAppConfigDirOverride = dir.path;
  });
  tearDown(() {
    debugAppConfigDirOverride = null;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return () => dir;
}
