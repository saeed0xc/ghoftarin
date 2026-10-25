// Every character the UI shows must exist in the bundled fonts; otherwise the
// web build silently downloads fallback fonts (or shows empty boxes).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<int> cmapOf(String path) {
  // minimal 'cmap' format-4 reader (BMP is enough for our text)
  final b = File(path).readAsBytesSync();
  int u16(int o) => (b[o] << 8) | b[o + 1];
  int u32(int o) => (u16(o) << 16) | u16(o + 2);
  final numTables = u16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    if (String.fromCharCodes(b.sublist(rec, rec + 4)) == 'cmap') cmap = u32(rec + 8);
  }
  final out = <int>{};
  final n = u16(cmap + 2);
  for (var i = 0; i < n; i++) {
    final sub = cmap + u32(cmap + 4 + i * 8 + 4);
    if (u16(sub) != 4) continue;
    final segX2 = u16(sub + 6);
    final ends = sub + 14, starts = ends + segX2 + 2;
    for (var s = 0; s < segX2; s += 2) {
      final e = u16(ends + s), st = u16(starts + s);
      for (var c = st; c <= e && c != 0xFFFF; c++) {
        out.add(c);
      }
    }
  }
  return out;
}

void main() {
  test('UI text is covered by Vazirmatn', () {
    final cmap = cmapOf('assets/fonts/Vazirmatn-Regular.ttf');
    final missing = <String, Set<String>>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('report.dart')) continue; // report is shared as plain text
      for (final m in RegExp(r"'([^'\n]*)'").allMatches(f.readAsStringSync())) {
        for (final r in m.group(1)!.runes) {
          if (r > 127 && r != 0x2713 && !cmap.contains(r)) {
            missing.putIfAbsent(f.path, () => {}).add(String.fromCharCode(r));
          }
        }
      }
    }
    expect(missing, isEmpty);
  });
}
