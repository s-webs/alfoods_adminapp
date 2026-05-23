import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../models/payment_split_line.dart';
import '../models/sale_payment_method.dart';

class MixedPaymentDialog extends StatefulWidget {
  const MixedPaymentDialog({
    super.key,
    required this.totalAmount,
    this.scrollController,
  });

  final double totalAmount;
  final ScrollController? scrollController;

  static bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static Future<List<PaymentSplitLine>?> show(
    BuildContext context, {
    required double totalAmount,
  }) {
    if (_isMobile(context)) {
      return showModalBottomSheet<List<PaymentSplitLine>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) => MixedPaymentDialog(
            totalAmount: totalAmount,
            scrollController: scrollController,
          ),
        ),
      );
    }
    return showDialog<List<PaymentSplitLine>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MixedPaymentDialog(totalAmount: totalAmount),
    );
  }

  @override
  State<MixedPaymentDialog> createState() => _MixedPaymentDialogState();
}

class _MixedPaymentDialogState extends State<MixedPaymentDialog> {
  final List<_SplitRowState> _rows = [];

  bool get _isMobile => MixedPaymentDialog._isMobile(context);

  @override
  void initState() {
    super.initState();
    _rows.add(_SplitRowState(method: SalePaymentMethod.cashOfd));
    _rows.add(_SplitRowState(method: SalePaymentMethod.kaspiQr));
    for (final row in _rows) {
      row.amountController.addListener(_onAmountChanged);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.amountController.removeListener(_onAmountChanged);
      row.amountController.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  double get _enteredTotal => _rows.fold(
        0,
        (sum, row) => sum + row.parsedAmount,
      );

  double get _remainder =>
      (widget.totalAmount - _enteredTotal).clamp(0, double.infinity);

  double get _change =>
      (_enteredTotal - widget.totalAmount).clamp(0, double.infinity);

  bool get _canAccept {
    if (_remainder > 0.009) return false;
    if (_rows.length < 2) return false;
    for (final row in _rows) {
      if (row.parsedAmount <= 0) return false;
    }
    return true;
  }

  void _addRow() {
    setState(() {
      final used = _rows.map((r) => r.method).toSet();
      SalePaymentMethod next = SalePaymentMethod.cashOfd;
      for (final m in SalePaymentMethod.adminOfdCheckoutMethods) {
        if (!used.contains(m)) {
          next = m;
          break;
        }
      }
      final row = _SplitRowState(method: next);
      row.amountController.addListener(_onAmountChanged);
      _rows.add(row);
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 2) return;
    setState(() {
      final row = _rows.removeAt(index);
      row.amountController.removeListener(_onAmountChanged);
      row.amountController.dispose();
    });
  }

  void _accept() {
    if (!_canAccept) return;
    final lines = _rows
        .map(
          (r) => PaymentSplitLine(
            method: r.method,
            amount: double.parse(r.parsedAmount.toStringAsFixed(2)),
          ),
        )
        .toList();
    Navigator.pop(context, lines);
  }

  void _fillRemainder(int index) {
    if (_remainder <= 0.009) return;
    _rows[index].amountController.text =
        _remainder.toStringAsFixed(2).replaceAll('.', ',');
    setState(() {});
  }

  static String _ordinalLabel(int index) {
    const labels = [
      'Первый способ',
      'Второй способ',
      'Третий способ',
      'Четвёртый способ',
      'Пятый способ',
    ];
    if (index < labels.length) return labels[index];
    return 'Способ ${index + 1}';
  }

  static double _dialogContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth - 48).clamp(280.0, 560.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile) {
      return _buildMobileSheet(context);
    }
    return _buildDesktopDialog(context);
  }

  Widget _buildMobileSheet(BuildContext context) {
    final scrollController = widget.scrollController;

    return Column(
      children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Смешанная оплата',
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
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                'Разбейте сумму на два и более способов оплаты. '
                'Для Kaspi QR и Halyk QR после «Принять оплату» откроется QR для подтверждения.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
              const SizedBox(height: 16),
              _SummaryGrid(
                total: widget.totalAmount,
                entered: _enteredTotal,
                remainder: _remainder,
                change: _change,
              ),
              const SizedBox(height: 20),
              ...List.generate(_rows.length, (index) {
                final row = _rows[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SplitRowEditor(
                    label: _ordinalLabel(index),
                    row: row,
                    compact: true,
                    canRemove: _rows.length > 2,
                    onRemove: () => _removeRow(index),
                    onMethodChanged: () => setState(() {}),
                    onFillRemainder: _remainder > 0.009
                        ? () => _fillRemainder(index)
                        : null,
                  ),
                );
              }),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _rows.length <
                          SalePaymentMethod.adminOfdCheckoutMethods.length
                      ? _addRow
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить способ оплаты'),
                ),
              ),
            ],
          ),
        ),
        _MobileActionsBar(
          canAccept: _canAccept,
          onCancel: () => Navigator.pop(context),
          onAccept: _accept,
        ),
      ],
    );
  }

  Widget _buildDesktopDialog(BuildContext context) {
    final width = _dialogContentWidth(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Смешанная оплата',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Подтвердите платеж, нажав «Принять оплату». '
                'Для QR-способов откроется окно с кодом для покупателя.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
              const SizedBox(height: 16),
              _SummaryBar(
                label: 'Итого к оплате',
                value: widget.totalAmount,
                highlighted: true,
              ),
              const SizedBox(height: 8),
              _SummaryBar(
                label: 'Внесено',
                value: _enteredTotal,
                highlighted: true,
              ),
              const SizedBox(height: 8),
              _SummaryBar(
                label: 'Остаток',
                value: _remainder,
                highlighted: _remainder > 0.009,
              ),
              const SizedBox(height: 8),
              _SummaryBar(
                label: 'Сдача',
                value: _change,
                highlighted: false,
              ),
              const SizedBox(height: 20),
              ...List.generate(_rows.length, (index) {
                final row = _rows[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SplitRowEditor(
                    label: _ordinalLabel(index),
                    row: row,
                    compact: false,
                    canRemove: _rows.length > 2,
                    onRemove: () => _removeRow(index),
                    onMethodChanged: () => setState(() {}),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _rows.length <
                          SalePaymentMethod.adminOfdCheckoutMethods.length
                      ? _addRow
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Способ оплаты'),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _canAccept ? _accept : null,
          icon: const Icon(Icons.check),
          label: const Text('Принять оплату'),
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

class _MobileActionsBar extends StatelessWidget {
  const _MobileActionsBar({
    required this.canAccept,
    required this.onCancel,
    required this.onAccept,
  });

  final bool canAccept;
  final VoidCallback onCancel;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canAccept ? onAccept : null,
                icon: const Icon(Icons.check),
                label: const Text(
                  'Принять оплату',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.total,
    required this.entered,
    required this.remainder,
    required this.change,
  });

  final double total;
  final double entered;
  final double remainder;
  final double change;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _SummaryTile(
          label: 'К оплате',
          value: total,
          primary: true,
        ),
        _SummaryTile(
          label: 'Внесено',
          value: entered,
          primary: true,
        ),
        _SummaryTile(
          label: 'Остаток',
          value: remainder,
          primary: remainder > 0.009,
          alert: remainder > 0.009,
        ),
        _SummaryTile(
          label: 'Сдача',
          value: change,
          primary: false,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.primary,
    this.alert = false,
  });

  final String label;
  final double value;
  final bool primary;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final bg = alert
        ? AppColors.danger
        : primary
            ? AppColors.primary
            : AppColors.muted.withValues(alpha: 0.2);
    final fg = primary || alert ? Colors.white : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg.withValues(alpha: primary || alert ? 0.9 : 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(2)} ₸',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitRowState {
  _SplitRowState({required this.method});

  SalePaymentMethod method;
  final TextEditingController amountController = TextEditingController();

  double get parsedAmount {
    final raw = amountController.text.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final String label;
  final double value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bg =
        highlighted ? AppColors.primary : AppColors.muted.withValues(alpha: 0.35);
    final fg = highlighted ? Colors.white : AppColors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(2)} ₸',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitRowEditor extends StatelessWidget {
  const _SplitRowEditor({
    required this.label,
    required this.row,
    required this.compact,
    required this.canRemove,
    required this.onRemove,
    required this.onMethodChanged,
    this.onFillRemainder,
  });

  final String label;
  final _SplitRowState row;
  final bool compact;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onMethodChanged;
  final VoidCallback? onFillRemainder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 0),
      decoration: compact
          ? BoxDecoration(
              border: Border.all(color: AppColors.muted.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Удалить',
                ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<SalePaymentMethod>(
              key: ValueKey(row.method),
              initialValue: row.method,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Способ оплаты',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: [
                for (final method in SalePaymentMethod.adminOfdCheckoutMethods)
                  DropdownMenuItem(
                    value: method,
                    child: Row(
                      children: [
                        if (method.paymentIconAsset != null)
                          Image.asset(
                            method.paymentIconAsset!,
                            width: 28,
                            height: 28,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 28,
                              height: 28,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(method.label)),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                row.method = value;
                onMethodChanged();
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,\s]')),
              ],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Сумма',
                suffixText: '₸',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            if (onFillRemainder != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onFillRemainder,
                  child: const Text('Подставить остаток'),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<SalePaymentMethod>(
                    key: ValueKey(row.method),
                    initialValue: row.method,
                    decoration: const InputDecoration(
                      labelText: 'Способ оплаты',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      for (final method
                          in SalePaymentMethod.adminOfdCheckoutMethods)
                        DropdownMenuItem(
                          value: method,
                          child: Row(
                            children: [
                              if (method.paymentIconAsset != null)
                                Image.asset(
                                  method.paymentIconAsset!,
                                  width: 28,
                                  height: 28,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 28,
                                    height: 28,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(method.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      row.method = value;
                      onMethodChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: row.amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,\s]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      suffixText: '₸',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
