import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_cyrillic_theme_io.dart'
    if (dart.library.html) 'pdf_cyrillic_theme_stub.dart'
    as fallback;

/// URL DejaVu Sans (Cyrillic) для загрузки, если шрифта нет в assets.
const _dejaVuSansUrl =
    'https://cdn.jsdelivr.net/npm/dejavu-fonts-ttf@2.37.2/ttf/DejaVuSans.ttf';

/// Загружает тему PDF с шрифтом, поддерживающим кириллицу.
/// 1) assets/fonts/DejaVuSans.ttf, 2) загрузка по URL, 3) Arial на Windows.
Future<pw.ThemeData?> loadCyrillicTheme() async {
  ByteData? byteData;

  try {
    byteData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  } catch (_) {}

  if (byteData == null) {
    try {
      final response = await Dio().get<List<int>>(
        _dejaVuSansUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && response.data!.isNotEmpty) {
        byteData = ByteData.view(Uint8List.fromList(response.data!).buffer);
      }
    } catch (_) {}
  }

  if (byteData != null) {
    try {
      final font = pw.Font.ttf(byteData);
      return pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      );
    } catch (_) {}
  }

  return fallback.loadCyrillicThemeWindowsFallback();
}
