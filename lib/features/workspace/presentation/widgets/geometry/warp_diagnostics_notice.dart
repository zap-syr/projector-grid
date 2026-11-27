import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../providers/warp_diagnostics_provider.dart';

/// Height of the strip in every state.
const double warpDiagnosticsNoticeHeight = 36;

const String _noticeText = 'Free grid is not available for this model yet.';
const String _saveLabel = 'Save diagnostics...';
const String _readingLabel = 'Reading';

/// The strip under the Geometry dialog's mode tiles for a model whose free
/// grid table format the app does not understand: says so and offers to save
/// what the projector's free grid memories hold, as a file for the developer.
/// Fills the width it is given.
class WarpDiagnosticsNotice extends ConsumerWidget {
  const WarpDiagnosticsNotice({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WarpDiagnosticsStrip(
      state: ref.watch(warpDiagnosticsProvider(nodeId)),
      onSave: () => ref.read(warpDiagnosticsProvider(nodeId).notifier).save(),
    );
  }
}

/// The strip for a given state; [WarpDiagnosticsNotice] feeds it from the
/// provider.
class WarpDiagnosticsStrip extends StatelessWidget {
  const WarpDiagnosticsStrip({
    super.key,
    required this.state,
    required this.onSave,
  });

  final WarpDiagnosticsState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final failed = state is WarpDiagnosticsFailed;
    final reading = state is WarpDiagnosticsReading;
    final message = switch (state) {
      WarpDiagnosticsSaved(:final fileName) => 'Diagnostics saved to $fileName',
      WarpDiagnosticsFailed(:final message) =>
        'Could not save diagnostics: $message',
      _ => _noticeText,
    };
    final color = failed ? cs.error : t.secondary;

    return SizedBox(
      height: warpDiagnosticsNoticeHeight,
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.description.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: reading ? null : onSave,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              splashFactory: NoSplash.splashFactory,
            ),
            // The longest label laid out invisibly under the real one sets
            // the width, so the button never changes size.
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(_saveLabel),
                ),
                if (reading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.disabled,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(_readingLabel),
                    ],
                  )
                else
                  const Text(_saveLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
