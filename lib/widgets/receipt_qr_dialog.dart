import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Диалог со ссылкой на чек: QR-код, копирование и открытие в браузере.
class ReceiptQrDialog extends StatelessWidget {
  const ReceiptQrDialog({
    super.key,
    required this.url,
    required this.title,
    this.hint = 'Отсканируйте QR-код для открытия чека',
  });

  final String url;
  final String title;
  final String hint;

  static bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static Future<void> show(
    BuildContext context, {
    required String url,
    required String title,
    String hint = 'Отсканируйте QR-код для открытия чека',
  }) {
    if (url.isEmpty) return Future.value();
    if (_isMobile(context)) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: ReceiptQrDialog(url: url, title: title, hint: hint),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ReceiptQrDialog(url: url, title: title, hint: hint),
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку на чек')),
        );
      }
    }
  }

  void _copyUrl(BuildContext context) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка на чек скопирована')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(24, mobile ? 16 : 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 212,
              height: 212,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.muted),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 180,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ссылка на чек:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SelectableText(url, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _copyUrl(context),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Скопировать ссылку'),
              ),
              FilledButton.icon(
                onPressed: () => _openUrl(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Открыть'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ],
      ),
    );

    if (mobile) {
      return content;
    }
    return content;
  }
}
