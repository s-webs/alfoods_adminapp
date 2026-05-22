import 'package:flutter/material.dart';

import '../models/sale_payment_method.dart';

class PosPaymentMethodDialog extends StatelessWidget {
  const PosPaymentMethodDialog({super.key});

  static Future<SalePaymentMethod?> show(BuildContext context) {
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
  ];

  static double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return screenWidth.clamp(560.0, 920.0) * 0.82;
  }

  @override
  Widget build(BuildContext context) {
    final width = _dialogWidth(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('POS Оплата'),
      content: SizedBox(
        width: width,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.15,
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

class _PaymentOption {
  const _PaymentOption({
    required this.method,
    required this.asset,
  });

  final SalePaymentMethod method;
  final String asset;
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
