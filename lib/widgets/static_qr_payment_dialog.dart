import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/sale_payment_method.dart';

/// Диалог статичного QR: покупатель платит в приложении банка, продавец подтверждает.
class StaticQrPaymentDialog extends StatelessWidget {
  const StaticQrPaymentDialog({
    super.key,
    required this.method,
    required this.amount,
  });

  final SalePaymentMethod method;
  final double amount;

  static bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static Future<bool> show(
    BuildContext context, {
    required SalePaymentMethod method,
    required double amount,
  }) async {
    if (!method.isStaticQrPayment || method.staticQrAsset == null) {
      return false;
    }
    if (!context.mounted) return false;

    final mobile = _isMobile(context);
    final bool? result;
    if (mobile) {
      result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => StaticQrPaymentDialog(
          method: method,
          amount: amount,
        ),
      );
    } else {
      result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StaticQrPaymentDialog(
          method: method,
          amount: amount,
        ),
      );
    }

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final qrAsset = method.staticQrAsset!;
    final mobile = _isMobile(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile) const _SheetHandle(),
        Padding(
          padding: EdgeInsets.fromLTRB(20, mobile ? 4 : 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  method.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Покупатель сканирует QR и вводит сумму в приложении банка. '
            'После оплаты нажмите «Оплачено».',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${amount.toStringAsFixed(2)} ₸',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.asset(
              qrAsset,
              fit: BoxFit.contain,
              semanticLabel: 'QR ${method.label}',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Оплачено',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (mobile) {
      return content;
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 420.0),
        child: content,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
