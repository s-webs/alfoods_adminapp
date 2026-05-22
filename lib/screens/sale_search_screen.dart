import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';
import '../services/receipt_pdf_service.dart';
import '../services/api_service.dart';
import '../utils/toast.dart';
import '../widgets/pdf_share_dialog.dart';

class SaleSearchScreen extends StatefulWidget {
  const SaleSearchScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<SaleSearchScreen> createState() => _SaleSearchScreenState();
}

class _SaleSearchScreenState extends State<SaleSearchScreen> {
  List<Sale> _filteredSales = [];
  bool _isLoading = false;
  bool _searched = false;
  int? _openingReceiptSaleId;
  String? _error;
  final _saleIdController = TextEditingController();
  final _webkassaCheckController = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void dispose() {
    _saleIdController.dispose();
    _webkassaCheckController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final saleIdText = _saleIdController.text.trim();
    final saleId = saleIdText.isEmpty ? null : int.tryParse(saleIdText);
    final webkassa = _webkassaCheckController.text.trim();

    setState(() {
      _isLoading = true;
      _error = null;
      _searched = true;
    });

    try {
      final page = await widget.apiService.searchSales(
        saleId: saleId,
        webkassaCheckNumber: webkassa.isEmpty ? null : webkassa,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        perPage: 100,
      );
      if (!mounted) return;
      setState(() {
        _filteredSales = List<Sale>.from(page.data)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось найти продажи';
        _isLoading = false;
        _filteredSales = [];
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openReceiptPdf(Sale sale) async {
    setState(() => _openingReceiptSaleId = sale.id);
    try {
      final fullSale = await widget.apiService.getSale(sale.id);
      final items = fullSale.items
          .map(
            (e) => CartItem(
              productId: e.productId,
              name: e.name,
              price: e.price,
              quantity: e.quantity,
              unit: e.unit,
            ),
          )
          .toList();
      final pdfBytes = await ReceiptPdfService.buildReceiptPdf(
        saleId: fullSale.id,
        cashierName: 'Касса',
        items: items,
        total: fullSale.totalPrice,
        dateTime: fullSale.createdAt,
      );
      final result = await widget.apiService.uploadPdf(pdfBytes, 'chek-${fullSale.id}.pdf');
      if (!mounted) return;
      showPdfShareDialog(context, url: result.url, title: 'Чек');
    } catch (_) {
      if (mounted) showToast(context, 'Не удалось открыть чек');
    } finally {
      if (mounted) setState(() => _openingReceiptSaleId = null);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.muted.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  'Поиск продажи',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _saleIdController,
                            decoration: const InputDecoration(
                              labelText: 'Номер продажи',
                              hintText: 'Необязательно',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.receipt_long),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _webkassaCheckController,
                            decoration: const InputDecoration(
                              labelText: '№ чека WebKassa',
                              hintText: 'Необязательно',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_error != null) ...[
                            Text(_error!, style: TextStyle(color: AppColors.danger)),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(true),
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(
                                    _dateFrom != null
                                        ? _formatDate(_dateFrom!).split(' ').first
                                        : 'Дата от',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(false),
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(
                                    _dateTo != null
                                        ? _formatDate(_dateTo!).split(' ').first
                                        : 'Дата до',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _search,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.search, size: 20),
                            label: Text(_isLoading ? 'Поиск...' : 'Искать'),
                          ),
                          const SizedBox(height: 24),
                          if (_searched) ...[
                            Text(
                              'Найдено: ${_filteredSales.length}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (_filteredSales.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Нет продаж по заданным условиям',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredSales.length,
                                itemBuilder: (context, index) {
                                  final sale = _filteredSales[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: sale.isReturned
                                            ? AppColors.muted.withValues(alpha: 0.3)
                                            : AppColors.primaryLight,
                                        child: Icon(
                                          Icons.receipt,
                                          color: sale.isReturned
                                              ? AppColors.muted
                                              : AppColors.primary,
                                        ),
                                      ),
                                      title: Text(
                                        sale.displayReceiptName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${sale.totalPrice.toStringAsFixed(2)} ₸',
                                            style: TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(sale.createdAt),
                                            style: TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sale.isReturned
                                                  ? AppColors.muted.withValues(alpha: 0.2)
                                                  : AppColors.primaryLight.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              sale.isReturned ? 'Возврат' : 'Продажа',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: sale.isReturned
                                                    ? AppColors.muted
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        tooltip: 'Открыть чек',
                                        onPressed: _openingReceiptSaleId == sale.id
                                            ? null
                                            : () => _openReceiptPdf(sale),
                                        icon: _openingReceiptSaleId == sale.id
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.picture_as_pdf),
                                      ),
                                      onTap: () async {
                                        final result = await context.push<bool>(
                                          '/sales/sale/${sale.id}',
                                        );
                                        if (result == true && mounted) _search();
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}
