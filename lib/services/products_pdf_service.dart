import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/product.dart';
import 'pdf_cyrillic_theme.dart';

/// Генерация PDF прайс-листа (название и цена).
class ProductsPdfService {
  static String _formatPrice(double v) {
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    return s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  static const int _rowsPerPagePortrait = 35;
  static const int _rowsPerPageLandscape = 28;

  static Future<Uint8List> buildPriceListPdf(List<Product> products) async {
    final theme = await loadCyrillicTheme();
    final pdf = pw.Document(theme: theme);
    final dateStr =
        '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

    for (var i = 0; i < products.length; i += _rowsPerPagePortrait) {
      final chunk = products
          .skip(i)
          .take(_rowsPerPagePortrait)
          .toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Прайс-лист',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Дата: $dateStr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FixedColumnWidth(80),
                  },
                  border: pw.TableBorder.all(width: 0.5),
                  children: _buildPriceListRows(chunk, startIndex: i + 1),
                ),
              ],
            );
          },
        ),
      );
    }
    if (products.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Прайс-лист',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Дата: $dateStr', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.Text('Нет товаров', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  /// Заканчивающиеся товары: остаток <= порог.
  /// Исключаются только товары, где остаток > порога.
  static Future<Uint8List> buildStockPdf(List<Product> products) async {
    final lowStock = products
        .where((p) => p.stock <= p.stockThreshold)
        .toList();
    final theme = await loadCyrillicTheme();
    final pdf = pw.Document(theme: theme);
    final dateStr =
        '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

    for (var i = 0; i < lowStock.length; i += _rowsPerPagePortrait) {
      final chunk = lowStock.skip(i).take(_rowsPerPagePortrait).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Остатки (заканчивающиеся товары)',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Дата: $dateStr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FixedColumnWidth(60),
                    3: const pw.FixedColumnWidth(60),
                    4: const pw.FixedColumnWidth(80),
                  },
                  border: pw.TableBorder.all(width: 0.5),
                  children: _buildStockRows(chunk, startIndex: i + 1),
                ),
              ],
            );
          },
        ),
      );
    }
    if (lowStock.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Остатки (заканчивающиеся товары)',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Дата: $dateStr', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.Text(
                'Нет заканчивающихся товаров',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  /// Ревизия: название, штрихкод, остаток, цена закупа, цена продажи, суммы активов, маржа.
  static Future<Uint8List> buildRevisionPdf(List<Product> products) async {
    final theme = await loadCyrillicTheme();
    final pdf = pw.Document(theme: theme);
    final dateStr =
        '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

    double totalPurchase = 0;
    double totalSale = 0;
    for (final p in products) {
      totalPurchase += p.stock * p.purchasePrice;
      totalSale += p.stock * p.effectivePrice;
    }

    for (var i = 0; i < products.length; i += _rowsPerPageLandscape) {
      final chunk = products.skip(i).take(_rowsPerPageLandscape).toList();
      final isLast = (i + chunk.length) >= products.length;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Ревизия',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Дата: $dateStr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FixedColumnWidth(80),
                    3: const pw.FixedColumnWidth(50),
                    4: const pw.FixedColumnWidth(55),
                    5: const pw.FixedColumnWidth(55),
                    6: const pw.FixedColumnWidth(55),
                    7: const pw.FixedColumnWidth(55),
                  },
                  border: pw.TableBorder.all(width: 0.5),
                  defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: _buildRevisionRows(
                    chunk,
                    totalPurchase,
                    totalSale,
                    startIndex: i + 1,
                    showFooter: isLast,
                  ),
                ),
                if (isLast) ...[
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Сумма активов (цена закупа): ${_formatPrice(totalPurchase)} ₸',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Text(
                        'Сумма активов (цена продажи): ${_formatPrice(totalSale)} ₸',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );
    }
    if (products.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Ревизия',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Дата: $dateStr', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('Нет товаров', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static List<pw.TableRow> _buildPriceListRows(
    List<Product> products, {
    int startIndex = 1,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cellRight('№', 10, bold: true),
          _cell('Название', 10, bold: true),
          _cellRight('Цена, ₸', 10, bold: true),
        ],
      ),
    ];
    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      rows.add(pw.TableRow(
        children: [
          _cellRight('${startIndex + i}', 9),
          _cell(p.name, 9),
          _cellRight(_formatPrice(p.effectivePrice), 9),
        ],
      ));
    }
    return rows;
  }

  static List<pw.TableRow> _buildStockRows(
    List<Product> lowStock, {
    int startIndex = 1,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cellRight('№', 10, bold: true),
          _cell('Название', 10, bold: true),
          _cellRight('Остаток', 10, bold: true),
          _cellRight('Порог', 10, bold: true),
          _cellRight('Цена, ₸', 10, bold: true),
        ],
      ),
    ];
    for (var i = 0; i < lowStock.length; i++) {
      final p = lowStock[i];
      rows.add(pw.TableRow(
        children: [
          _cellRight('${startIndex + i}', 9),
          _cell(p.name, 9),
          _cellRight(_formatStock(p.stock), 9),
          _cellRight(_formatStock(p.stockThreshold), 9),
          _cellRight(_formatPrice(p.effectivePrice), 9),
        ],
      ));
    }
    return rows;
  }

  static List<pw.TableRow> _buildRevisionRows(
    List<Product> products,
    double totalPurchase,
    double totalSale, {
    int startIndex = 1,
    bool showFooter = true,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cellRight('№', 8, bold: true),
          _cell('Название', 8, bold: true),
          _cell('Штрихкод', 8, bold: true),
          _cellRight('Остаток', 8, bold: true),
          _cellRight('Цена зак.', 8, bold: true),
          _cellRight('Цена прод.', 8, bold: true),
          _cellRight('Сумма прод.', 8, bold: true),
          _cellRight('Маржа', 8, bold: true),
        ],
      ),
    ];
    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      final purchaseSum = p.stock * p.purchasePrice;
      final saleSum = p.stock * p.effectivePrice;
      final margin = saleSum - purchaseSum;
      rows.add(pw.TableRow(
        children: [
          _cellRight('${startIndex + i}', 7),
          _cell(p.name, 7),
          _cell(p.barcode ?? '—', 7),
          _cellRight(_formatStock(p.stock), 7),
          _cellRight(_formatPrice(p.purchasePrice), 7),
          _cellRight(_formatPrice(p.effectivePrice), 7),
          _cellRight(_formatPrice(saleSum), 7),
          _cellRight(_formatPrice(margin), 7),
        ],
      ));
    }
    if (showFooter) {
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cellRight('', 9),
          _cell('Итого', 9, bold: true),
          _cell('', 9),
          _cellRight('', 9),
          _cellRight('', 9),
          _cellRight('', 9),
          _cellRight(_formatPrice(totalSale), 9, bold: true),
          _cellRight(
            _formatPrice(totalSale - totalPurchase),
            9,
            bold: true,
          ),
        ],
      ));
    }
    return rows;
  }

  static pw.Widget _cell(String text, double fontSize, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _cellRight(String text, double fontSize, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.right,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static String _formatStock(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// Сохраняет PDF во временную директорию и возвращает путь.
  static Future<String> saveToTempFile(
    Uint8List bytes,
    String filename,
  ) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }
}
