import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/counterparty.dart';
import '../models/product.dart';
import '../models/product_set.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import '../services/receipt_pdf_service.dart';
import '../state/cashier_state.dart';
import '../utils/toast.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/invoice_dialog.dart';
import 'barcode_scanner_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({
    super.key,
    required this.storage,
    required this.apiService,
  });

  final Storage storage;
  final ApiService apiService;

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  List<Counterparty> _counterparties = [];
  Shift? _openShift;
  bool _isLoading = true;
  bool _isSelling = false;
  bool _isResetting = false;
  int? _editingPriceIndex;
  TextEditingController? _priceEditController;
  CashierState? _state;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = CashierStateScope.of(context);
    if (_state != state) {
      if (_listenerAdded && _state != null) {
        _state!.removeListener(_onStateChanged);
        _listenerAdded = false;
      }
      _state = state;
      _state!.addListener(_onStateChanged);
      _listenerAdded = true;
    }
  }

  @override
  void dispose() {
    if (_listenerAdded && _state != null) {
      _state!.removeListener(_onStateChanged);
    }
    _priceEditController?.dispose();
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  CashierState get _cashierState => _state!;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final shifts = await widget.apiService.getShifts();
      final counterparties = await widget.apiService.getCounterparties();
      if (!mounted) return;
      final open = shifts.where((s) => s.isOpen).firstOrNull;
      setState(() {
        _openShift = open;
        _counterparties = counterparties;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addProduct(Product product) {
    final step = product.unit == 'pcs' ? 1.0 : 0.1;
    _cashierState.addOrIncrementQuantity(
      product.id,
      step,
      CartItem(
        productId: product.id,
        name: product.name,
        price: product.effectivePrice,
        quantity: 1,
        unit: product.unit,
      ),
    );
  }

  void _addSet(ProductSet set) {
    _cashierState.addOrIncrementQuantity(
      0,
      1,
      CartItem(
        productId: 0,
        setId: set.id,
        name: set.name,
        price: set.effectivePrice,
        quantity: 1,
        unit: 'pcs',
      ),
      setId: set.id,
    );
  }

  Future<void> _openAddProductDialog() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) => AddProductDialog(
        apiService: widget.apiService,
        onAddProduct: (p) {
          _addProduct(p);
          Navigator.of(ctx).pop();
        },
        onAddSet: (s) {
          _addSet(s);
          Navigator.of(ctx).pop();
        },
      ),
    );
    if (result != null && mounted) {
      if (result is Product) _addProduct(result);
      if (result is ProductSet) _addSet(result);
    }
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result == null || result.trim().isEmpty || !mounted) return;
    final barcode = result.trim();
    try {
      final product = await widget.apiService.getProductByBarcode(barcode);
      if (!mounted) return;
      if (product != null) {
        _addProduct(product);
        showToast(context, 'Добавлено: ${product.name}');
      } else {
        final productSet = await widget.apiService.getSetByBarcode(barcode);
        if (!mounted) return;
        if (productSet != null) {
          _addSet(productSet);
          showToast(context, 'Добавлено: ${productSet.name}');
        } else {
          showToast(context, 'Товар с штрихкодом "$barcode" не найден');
        }
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка поиска товара');
    }
  }

  void _startEditPrice(int index) {
    _priceEditController?.dispose();
    final item = _cashierState.cart[index];
    _priceEditController = TextEditingController(text: item.price.toString());
    setState(() => _editingPriceIndex = index);
  }

  void _finishEditPrice({bool save = false}) {
    if (_editingPriceIndex == null || _priceEditController == null) return;
    final index = _editingPriceIndex!;
    if (save && index < _cashierState.cart.length) {
      final v = double.tryParse(
        _priceEditController!.text.replaceAll(',', '.'),
      );
      if (v != null && v >= 0) {
        _cashierState.updatePriceAt(index, v);
      }
    }
    _priceEditController?.dispose();
    _priceEditController = null;
    setState(() => _editingPriceIndex = null);
  }

  void _editQuantity(int index) async {
    final item = _cashierState.cart[index];
    final controller = TextEditingController(
      text: item.quantity.toStringAsFixed(item.unit == 'pcs' ? 0 : 2),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Количество'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Кол-во (${item.unit})',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && mounted && index < _cashierState.cart.length) {
      final v = double.tryParse(result.replaceAll(',', '.'));
      if (v != null && v > 0) {
        _cashierState.updateQuantityAt(index, v);
      }
    }
  }

  void _updateQuantity(int index, int delta) {
    if (index < 0 || index >= _cashierState.cart.length) return;
    final item = _cashierState.cart[index];
    final step = item.unit == 'pcs' ? 1.0 : 0.1;
    var q = item.quantity + (delta * step);
    if (q < step) q = step;
    _cashierState.updateQuantityAt(index, q);
  }

  void _resetCart() {
    if (_cashierState.cart.isEmpty) return;
    setState(() => _isResetting = true);
    _cashierState.clearCart();
    setState(() => _isResetting = false);
    showToast(context, 'Корзина очищена');
  }

  Future<void> _saveReceiptPdf() async {
    if (_cashierState.cart.isEmpty) {
      showToast(context, 'Нет позиций для чека');
      return;
    }
    try {
      final pdfBytes = await ReceiptPdfService.buildReceiptPdf(
        saleId: 0,
        cashierName: 'Касса',
        items: _cashierState.cart,
        total: _cashierState.cartTotal,
        dateTime: DateTime.now(),
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить чек в PDF',
        fileName: 'chek-${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );
      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        showToast(context, 'Чек сохранён: $path');
      }
    } catch (e) {
      if (!mounted) return;
      showToast(
        context,
        'Ошибка: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _openInvoiceDialog() {
    if (_cashierState.cart.isEmpty) {
      showToast(context, 'Нет позиций для накладной');
      return;
    }
    showInvoiceDialog(
      context: context,
      apiService: widget.apiService,
      items: List.from(_cashierState.cart),
      storage: widget.storage,
    );
  }

  Future<void> _pickCounterpartyForCredit() async {
    if (_counterparties.isEmpty) {
      showToast(context, 'Нет контрагентов');
      return;
    }
    final selected = await showDialog<Counterparty>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Продажа в долг — выберите контрагента'),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _counterparties.length,
            itemBuilder: (context, i) {
              final c = _counterparties[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.muted.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(c.name),
                    subtitle: c.iin != null ? Text('ИИН/БИН: ${c.iin}') : null,
                    onTap: () => Navigator.pop(ctx, c),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      _cashierState.setCredit(selected.id);
      showToast(context, 'В долг: ${selected.name}');
    }
  }

  void _clearCredit() {
    _cashierState.clearCredit();
  }

  Future<void> _sell() async {
    if (_cashierState.cart.isEmpty) {
      showToast(context, 'Добавьте товары в корзину');
      return;
    }
    if (_openShift == null) {
      showToast(
        context,
        'Нет открытой смены. Откройте смену в приложении кассы.',
      );
      return;
    }
    if (_cashierState.isOnCredit &&
        _cashierState.selectedCounterpartyId == null) {
      showToast(context, 'Выберите контрагента для продажи в долг');
      return;
    }
    setState(() => _isSelling = true);
    try {
      final sale = await widget.apiService.createSale(
        shiftId: _openShift!.id,
        counterpartyId: _cashierState.selectedCounterpartyId,
        isOnCredit: _cashierState.isOnCredit,
        items: _cashierState.cart.map((e) => e.toJson()).toList(),
      );
      if (!mounted) return;
      _cashierState.clearCart();
      setState(() => _isSelling = false);
      showToast(context, 'Продажа #${sale.id} оформлена');
      context.push('/sales/sale/${sale.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSelling = false);
      showToast(
        context,
        'Ошибка: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openAddProductDialog,
                  icon: const Icon(PhosphorIconsRegular.plus, size: 20),
                  label: const Text('Добавить товар вручную'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _openBarcodeScanner,
                icon: const Icon(PhosphorIconsRegular.barcode),
                tooltip: 'Сканировать штрихкод',
              ),
            ],
          ),
        ),
        Expanded(
          child: _cashierState.cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIconsRegular.shoppingCart,
                        size: 64,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Корзина пуста',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._cashierState.cart.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _startEditPrice(index),
                                    child:
                                        (_editingPriceIndex == index &&
                                            _priceEditController != null)
                                        ? SizedBox(
                                            width: 100,
                                            child: TextField(
                                              controller: _priceEditController,
                                              autofocus: true,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                              ),
                                              onSubmitted: (_) =>
                                                  _finishEditPrice(save: true),
                                              onEditingComplete: () =>
                                                  _finishEditPrice(save: true),
                                            ),
                                          )
                                        : Text(
                                            '${item.price.toStringAsFixed(2)} ₸ × ',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _editQuantity(index),
                                    child: Text(
                                      '${item.quantity.toStringAsFixed(item.unit == 'pcs' ? 0 : 2)} ${item.unit}',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${item.total.toStringAsFixed(2)} ₸',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: () => _updateQuantity(index, -1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => _updateQuantity(index, 1),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppColors.danger,
                                    onPressed: () {
                                      _cashierState.removeAt(index);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.muted.withValues(alpha: 0.5)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cashierState.cart.isEmpty
                          ? null
                          : _saveReceiptPdf,
                      icon: const Icon(Icons.receipt_long, size: 20),
                      label: const Text('Чек'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cashierState.cart.isEmpty
                          ? null
                          : _openInvoiceDialog,
                      icon: const Icon(Icons.description, size: 20),
                      label: const Text('Накладная'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _cashierState.isOnCredit
                              ? FilledButton.tonal(
                                  onPressed: _pickCounterpartyForCredit,
                                  child: Text(
                                    _counterparties
                                            .where(
                                              (c) =>
                                                  c.id ==
                                                  _cashierState
                                                      .selectedCounterpartyId,
                                            )
                                            .firstOrNull
                                            ?.name ??
                                        'В долг',
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: _pickCounterpartyForCredit,
                                  icon: const Icon(Icons.credit_card, size: 20),
                                  label: const Text('В долг'),
                                ),
                        ),
                        if (_cashierState.isOnCredit)
                          IconButton(
                            onPressed: _clearCredit,
                            icon: const Icon(Icons.close),
                            tooltip: 'Отменить продажу в долг',
                          ),
                      ],
                    ),
                  ),
                  if (_cashierState.cart.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isResetting ? null : _resetCart,
                        icon: _isResetting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.clear_all, size: 20),
                        label: Text(_isResetting ? 'Сброс...' : 'Сброс'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Итого: ${_cashierState.cartTotal.toStringAsFixed(2)} ₸',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isSelling || _cashierState.cart.isEmpty
                        ? null
                        : _sell,
                    child: _isSelling
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Продать'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
