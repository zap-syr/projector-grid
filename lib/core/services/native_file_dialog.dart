import 'dart:io';

/// The signature of [showNativeSaveDialog], so a provider can hand it out and
/// a test can replace it with a function that opens nothing.
typedef NativeSaveDialog = Future<String?> Function({
  required String title,
  required String defaultName,
  required String filterLabel,
  required String extension,
  String? initialDirectory,
});

/// Asks for a file to save to with the operating system's own dialog (a
/// PowerShell `SaveFileDialog` on Windows, `choose file name` on macOS), so no
/// plugin is needed. Returns null when the user cancels, and on a platform
/// without a dialog.
///
/// [defaultName] gets [extension] (without the dot) appended when it lacks
/// it. [filterLabel] names the file type in the Windows filter list, as in
/// `Text file (*.txt)`. [initialDirectory] must exist: the dialog is not
/// asked to create it.
Future<String?> showNativeSaveDialog({
  required String title,
  required String defaultName,
  required String filterLabel,
  required String extension,
  String? initialDirectory,
}) async {
  final name = defaultName.endsWith('.$extension')
      ? defaultName
      : '$defaultName.$extension';
  if (Platform.isWindows) {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      windowsSaveDialogScript(
        title: title,
        defaultName: name,
        filterLabel: filterLabel,
        extension: extension,
        initialDirectory: initialDirectory,
      ),
    ]);
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  } else if (Platform.isMacOS) {
    final result = await Process.run('osascript', [
      '-e',
      macSaveDialogScript(
        title: title,
        defaultName: name,
        initialDirectory: initialDirectory,
      ),
    ]);
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }
  return null;
}

/// A value inside a PowerShell single-quoted string literal.
String _psQuoted(String value) => "'${value.replaceAll("'", "''")}'";

/// The PowerShell script of the Windows save dialog; it prints the chosen
/// path, or nothing when the dialog is cancelled. Shown on top of every other
/// window through a topmost owner form.
String windowsSaveDialogScript({
  required String title,
  required String defaultName,
  required String filterLabel,
  required String extension,
  String? initialDirectory,
}) {
  final filter = '$filterLabel (*.$extension)|*.$extension';
  return '''
Add-Type -AssemblyName System.Windows.Forms
\$owner = New-Object System.Windows.Forms.Form
\$owner.TopMost = \$true
\$dialog = New-Object System.Windows.Forms.SaveFileDialog
\$dialog.Filter = ${_psQuoted(filter)}
\$dialog.DefaultExt = ${_psQuoted(extension)}
\$dialog.FileName = ${_psQuoted(defaultName)}
${initialDirectory == null ? '' : '\$dialog.InitialDirectory = ${_psQuoted(initialDirectory)}\n'}\$dialog.Title = ${_psQuoted(title)}
\$r = \$dialog.ShowDialog(\$owner)
\$owner.Dispose()
if (\$r -eq 'OK') { Write-Output \$dialog.FileName }
''';
}

/// A value inside an AppleScript string literal.
String _asQuoted(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// The AppleScript of the macOS save dialog; it prints the chosen POSIX path.
String macSaveDialogScript({
  required String title,
  required String defaultName,
  String? initialDirectory,
}) {
  final location = initialDirectory == null
      ? ''
      : ' default location POSIX file ${_asQuoted(initialDirectory)}';
  return 'POSIX path of (choose file name with prompt ${_asQuoted(title)} '
      'default name ${_asQuoted(defaultName)}$location)';
}
