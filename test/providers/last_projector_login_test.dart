import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';

import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  test('the last used projector login is saved and read back', () {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    expect(first.read(appSettingsProvider).lastProjectorLogin, '');

    first
        .read(appSettingsProvider.notifier)
        .setLastProjectorLogin('admin1', 'panasonic');

    // A fresh container reads the settings file again, as the next launch.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    final settings = second.read(appSettingsProvider);
    expect(settings.lastProjectorLogin, 'admin1');
    expect(settings.lastProjectorPassword, 'panasonic');
  });
}
