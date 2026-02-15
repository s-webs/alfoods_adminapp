import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Загрузка шрифта Arial с Windows (fallback, если нет asset).
Future<pw.ThemeData?> loadCyrillicThemeWindowsFallback() async {
  if (!Platform.isWindows) return null;
  try {
    final file = File(r'C:\Windows\Fonts\arial.ttf');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final font = pw.Font.ttf(bytes.buffer.asByteData());
      return pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      );
    }
  } catch (_) {}
  return null;
}
