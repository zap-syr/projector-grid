import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/services/external_links.dart';
import '../../../../core/theme/app_theme.dart';
import 'common/dialog_parts.dart';
import 'common/scroll_fade.dart';
import 'dialog_title_bar.dart';

class AppAboutDialog extends StatefulWidget {
  const AppAboutDialog({super.key});

  static const repoUrl = 'https://github.com/zap-syr/projector-grid';
  static const newIssueUrl = '$repoUrl/issues/new';
  static const supportUrl = 'https://projectorhub.gumroad.com/l/projectorgrid';
  static String releaseNotesUrl(String version) =>
      '$repoUrl/releases/tag/v$version';

  @override
  State<AppAboutDialog> createState() => _AppAboutDialogState();
}

class _AppAboutDialogState extends State<AppAboutDialog> {
  static const _appName = 'Projector Grid';
  static const _author = 'Aleksei Vlasov';

  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  void _openLicenses() {
    final navigator = Navigator.of(context);
    navigator.pop();
    showLicensePage(
      context: navigator.context,
      applicationName: _appName,
      applicationVersion: _info?.version ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final info = _info;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 615),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(icon: Icons.info_outline, title: 'About'),
            Flexible(
              child: ScrollFade(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    children: [
                      const _AppIcon(),
                      const SizedBox(height: 12),
                      Text(_appName, style: t.hero),
                      const SizedBox(height: 8),
                      // Height held while PackageInfo loads, so the rows
                      // below don't jump when the pill appears.
                      SizedBox(
                        height: 24,
                        child: info == null
                            ? null
                            : _VersionPill(
                                'Version ${info.version} (build ${info.buildNumber})',
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text.rich(
                        const TextSpan(
                          text: 'Made by ',
                          children: [
                            TextSpan(
                              text: _author,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        style: t.cardTitle.copyWith(
                          fontWeight: FontWeight.w400,
                          color: t.secondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _LinksCard(
                        children: [
                          _LinkRow(
                            icon: Icons.new_releases_outlined,
                            label: info == null
                                ? "What's new"
                                : "What's new in ${info.version}",
                            hint: 'Release notes',
                            onTap: info == null
                                ? null
                                : () => openInBrowser(
                                    AppAboutDialog.releaseNotesUrl(
                                      info.version,
                                    ),
                                  ),
                          ),
                          _LinkRow(
                            icon: Icons.public,
                            label: 'Project page',
                            hint: 'github.com/zap-syr',
                            onTap: () => openInBrowser(AppAboutDialog.repoUrl),
                          ),
                          _LinkRow(
                            icon: Icons.bug_report_outlined,
                            label: 'Report a bug',
                            hint: 'GitHub issues',
                            onTap: () =>
                                openInBrowser(AppAboutDialog.newIssueUrl),
                          ),
                          _LinkRow(
                            icon: Icons.description_outlined,
                            label: 'Third-party licenses',
                            inApp: true,
                            onTap: _openLicenses,
                          ),
                          _LinkRow(
                            icon: Icons.favorite,
                            label: 'Support the project',
                            hint: 'gumroad.com',
                            heart: true,
                            onTap: () =>
                                openInBrowser(AppAboutDialog.supportUrl),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: DialogSurfaces.of(context).card,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '© 2025–2026 $_author',
                  textAlign: TextAlign.center,
                  style: t.description,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/launcher_icon/app_icon_160.png',
          width: 80,
          height: 80,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    // The Column hands the pill a loose width, and Container with an
    // alignment would fill it; widthFactor keeps it to the text. Neutral,
    // not primary: a blue fill is kept for state.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: t.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: t.secondary,
          ),
        ),
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DialogCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 10,
                endIndent: 10,
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
            child,
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.inApp = false,
    this.heart = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  /// Opens inside the app: a chevron instead of the external-link icon.
  final bool inApp;

  /// The support row's pink tile.
  final bool heart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final dark = cs.brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: Padding(
        // The link's own 6px padding brings the trailing icon back to 10px
        // from the edge, level with the tile on the left.
        padding: const EdgeInsets.only(left: 10, right: 4),
        child: Row(
          children: [
            if (heart)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: dark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: dark ? Colors.pink.shade100 : Colors.pink.shade600,
                ),
              )
            else
              DialogIconTile(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body,
              ),
            ),
            const SizedBox(width: 6),
            // Only the hint and its icon are the link, not the whole row.
            InkWell(
              onTap: onTap,
              mouseCursor: onTap == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hint != null) ...[
                      Text(hint!, style: t.monoSmall),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      inApp ? Icons.chevron_right : Icons.open_in_new,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
