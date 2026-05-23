import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/sale_payment_method.dart';

class PosPaymentMethodDialog extends StatelessWidget {
  const PosPaymentMethodDialog({super.key});

  static bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static Future<SalePaymentMethod?> show(BuildContext context) {
    if (_isMobile(context)) {
      return showModalBottomSheet<SalePaymentMethod>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => const PosPaymentMethodDialog(),
      );
    }
    return showDialog<SalePaymentMethod>(
      context: context,
      builder: (ctx) => const PosPaymentMethodDialog(),
    );
  }

  static const _options = <_PaymentOption>[
    _PaymentOption(
      method: SalePaymentMethod.cashOfd,
      asset: 'assets/payments_type/cash.png',
    ),
    _PaymentOption(
      method: SalePaymentMethod.cardOfd,
      asset: 'assets/payments_type/card.png',
    ),
    _PaymentOption(
      method: SalePaymentMethod.mobileOfd,
      asset: 'assets/payments_type/mobile.png',
    ),
    _PaymentOption(
      method: SalePaymentMethod.kaspiQr,
      asset: 'assets/payments_type/kaspiQR.png',
    ),
    _PaymentOption(
      method: SalePaymentMethod.halykQr,
      asset: 'assets/payments_type/halykQR.png',
    ),
  ];

  static int _gridCrossAxisCount(double width) {
    if (width < 600) return 1;
    return 2;
  }

  static double _dialogContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth - 48).clamp(280.0, 520.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile(context)) {
      return _buildMobileSheet(context);
    }
    return _buildDesktopDialog(context);
  }

  Widget _buildMobileSheet(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'POS Оплата',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите способ оплаты',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: 12),
          ..._options.map(
            (option) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _MobileOptionTile(
                option: option,
                onTap: () => Navigator.pop(context, option.method),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDialog(BuildContext context) {
    final width = _dialogContentWidth(context);
    final crossAxisCount = _gridCrossAxisCount(MediaQuery.sizeOf(context).width);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('POS Оплата'),
      content: SizedBox(
        width: width,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 3.2 : 2.15,
          ),
          itemCount: _options.length,
          itemBuilder: (context, index) {
            final option = _options[index];
            return _OptionTile(
              asset: option.asset,
              label: option.method.label,
              onTap: () => Navigator.pop(context, option.method),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
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

class _PaymentOption {
  const _PaymentOption({
    required this.method,
    required this.asset,
  });

  final SalePaymentMethod method;
  final String asset;
}

class _MobileOptionTile extends StatelessWidget {
  const _MobileOptionTile({
    required this.option,
    required this.onTap,
  });

  final _PaymentOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.muted.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  option.asset,
                  width: 72,
                  height: 40,
                  fit: BoxFit.contain,
                  semanticLabel: option.method.label,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option.method.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            asset,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}
