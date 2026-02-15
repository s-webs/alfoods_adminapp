import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';

/// Диалог с ссылкой на PDF, QR-кодом и кнопкой «Поделиться».
void showPdfShareDialog(
  BuildContext context, {
  required String url,
  required String title,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$title загружен',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ссылка на PDF:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SelectableText(url, style: const TextStyle(fontSize: 12)),
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
              const SizedBox(height: 8),
              Text(
                'Отсканируйте QR-код для открытия PDF',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Share.share('$title: $url');
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Поделиться'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ссылка скопирована в буфер'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Копировать'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
