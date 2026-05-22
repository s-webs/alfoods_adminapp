import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/z_report_formatter.dart';

/// Просмотр Z-отчёта WebKassa.
class ZReportDialog extends StatelessWidget {
  const ZReportDialog({
    super.key,
    required this.zReport,
    this.zReportAt,
  });

  final Map<String, dynamic> zReport;
  final DateTime? zReportAt;

  static bool hasViewableData(Map<String, dynamic>? zReport) {
    return zReport != null && zReport.isNotEmpty;
  }

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> zReport,
    DateTime? zReportAt,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ZReportDialog(
        zReport: zReport,
        zReportAt: zReportAt,
      ),
    );
  }

  List<({String label, String value})> _rows() {
    final lines = ZReportFormatter.formatLines(zReport, zReportAt: zReportAt);
    final rows = <({String label, String value})>[];
    for (final line in lines.skip(1)) {
      if (line.startsWith('---')) {
        rows.add((label: line, value: ''));
        continue;
      }
      final colon = line.indexOf(': ');
      if (colon > 0) {
        rows.add((
          label: line.substring(0, colon),
          value: line.substring(colon + 2),
        ));
      } else {
        rows.add((label: '', value: line));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();

    return AlertDialog(
      title: const Text('Z-отчёт WebKassa'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...rows.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: r.value.isEmpty
                      ? Text(
                          r.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 150,
                              child: Text(
                                r.label,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                r.value,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
