import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/native_file_dialog.dart';

void main() {
  group('windowsSaveDialogScript', () {
    test('keeps the Save Project dialog it was moved from', () {
      final script = windowsSaveDialogScript(
        title: 'Save Project',
        defaultName: 'project.pgrid',
        filterLabel: 'Projector Grid Project',
        extension: 'pgrid',
      );
      expect(
        script,
        contains(
          r"$dialog.Filter = 'Projector Grid Project (*.pgrid)|*.pgrid'",
        ),
      );
      expect(script, contains(r"$dialog.DefaultExt = 'pgrid'"));
      expect(script, contains(r"$dialog.FileName = 'project.pgrid'"));
      expect(script, contains(r"$dialog.Title = 'Save Project'"));
      expect(script, isNot(contains('InitialDirectory')));
      expect(script, contains(r'$owner.TopMost = $true'));
      expect(
        script,
        contains(r"if ($r -eq 'OK') { Write-Output $dialog.FileName }"),
      );
    });

    test('sets the initial folder and escapes single quotes', () {
      final script = windowsSaveDialogScript(
        title: "Don't",
        defaultName: "it's.txt",
        filterLabel: 'Text file',
        extension: 'txt',
        initialDirectory: r"C:\Users\O'Neil\logs",
      );
      expect(script, contains(r"$dialog.Filter = 'Text file (*.txt)|*.txt'"));
      expect(script, contains(r"$dialog.FileName = 'it''s.txt'"));
      expect(script, contains(r"$dialog.Title = 'Don''t'"));
      expect(
        script,
        contains(r"$dialog.InitialDirectory = 'C:\Users\O''Neil\logs'"),
      );
    });
  });

  group('macSaveDialogScript', () {
    test('names the prompt and the default name', () {
      expect(
        macSaveDialogScript(title: 'Save Project', defaultName: 'a.pgrid'),
        'POSIX path of (choose file name with prompt "Save Project" '
        'default name "a.pgrid")',
      );
    });

    test('sets the default folder and escapes quotes and backslashes', () {
      final script = macSaveDialogScript(
        title: 'Save "x"',
        defaultName: r'a\b.txt',
        initialDirectory: '/Users/me/Library/Application Support/Logs',
      );
      expect(script, contains(r'prompt "Save \"x\""'));
      expect(script, contains(r'default name "a\\b.txt"'));
      expect(
        script,
        contains(
          'default location (POSIX file '
          '"/Users/me/Library/Application Support/Logs")',
        ),
      );
    });
  });
}
