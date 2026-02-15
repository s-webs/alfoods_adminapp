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
import '../widgets/pdf_share_dialog.dart';
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
  bool _isReturnMode = false;
  bool _isAcceptingReturn = false;
  bool _isResetting = false;
  bool _isSavingReceiptPdf = false;
  String? _error;
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AddProductDialog(
        apiService: widget.apiService,
        onAddProduct: (p) => _addProduct(p),
        onAddSet: (s) => _addSet(s),
      ),
    );
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
          await _showBarcodeNotFoundDialog(barcode);
        }
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка поиска товара');
    }
  }

  Future<void> _showBarcodeNotFoundDialog(String barcode) async {
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Товар не найден'),
        content: Text(
          'Штрихкод «$barcode» не найден в каталоге. Что сделать?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('cart'),
            child: const Text('Добавить в корзину (только на эту продажу)'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('product'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Добавить товар в базу'),
          ),
        ],
      ),
    );
    if (choice == 'cart' && mounted) {
      await _showAddSnapshotToCartDialog(barcode);
    } else if (choice == 'product' && mounted) {
      await context.push(
        '/products/create?barcode=${Uri.encodeComponent(barcode)}',
      );
      if (!mounted) return;
      final product = await widget.apiService.getProductByBarcode(barcode);
      if (product != null && mounted) {
        _addProduct(product);
        showToast(context, 'Добавлено: ${product.name}');
      }
    }
  }

  Future<void> _showAddSnapshotToCartDialog(String barcode) async {
    final nameController = TextEditingController(text: 'Товар $barcode');
    final priceController = TextEditingController(text: '0');
    String unit = 'pcs';
    final quantityController = TextEditingController(text: '1');

    if (!mounted) return;
    final result = await showDialog<
        ({String name, double price, String unit, double quantity})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить в корзину (только на эту продажу)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Цена, ₸',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(
                    labelText: 'Единица',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pcs', child: Text('шт')),
                    DropdownMenuItem(value: 'g', child: Text('г')),
                  ],
                  onChanged: (v) => setDialogState(() => unit = v ?? 'pcs'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price =
                    double.tryParse(priceController.text.replaceAll(',', '.')) ??
                        0;
                final qty =
                    double.tryParse(
                        quantityController.text.replaceAll(',', '.')) ??
                        1;
                if (name.isEmpty) return;
                Navigator.pop(ctx, (name: name, price: price, unit: unit, quantity: qty));
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      _cashierState.addItem(
        CartItem(
          productId: 0,
          name: result.name,
          price: result.price,
          quantity: result.quantity,
          unit: result.unit,
        ),
      );
      showToast(context, 'Добавлено: ${result.name}');
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
    setState(() => _isSavingReceiptPdf = true);
    try {
      final pdfBytes = await ReceiptPdfService.buildReceiptPdf(
        saleId: 0,
        cashierName: 'Касса',
        items: _cashierState.cart,
        total: _cashierState.cartTotal,
        dateTime: DateTime.now(),
      );
      final filename =
          'chek-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final result = await widget.apiService.uploadPdf(pdfBytes, filename);
      if (!mounted) return;
      showPdfShareDialog(
        context,
        url: result.url,
        title: 'Чек',
      );
    } catch (e) {
      if (!mounted) return;
      showToast(
        context,
        'Ошибка: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _isSavingReceiptPdf = false);
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

  Future<void> _acceptReturn() async {
    if (_cashierState.cart.isEmpty) return;
    setState(() {
      _isAcceptingReturn = true;
      _error = null;
    });
    try {
      await widget.apiService.acceptReturn(
        items: _cashierState.cart.map((e) => e.toJson()).toList(),
        shiftId: _openShift?.id,
        cashierId: null,
      );
      if (!mounted) return;
      _cashierState.clearCart();
      setState(() => _isAcceptingReturn = false);
      showToast(context, 'Возврат принят');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAcceptingReturn = false;
        _error = 'Не удалось принять возврат';
      });
    }
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

    return Stack(
      children: [
        Column(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: _isReturnMode
                    ? OutlinedButton.icon(
                        onPressed: _isAcceptingReturn
                            ? null
                            : () {
                                setState(() {
                                  _isReturnMode = false;
                                  _error = null;
                                });
                                _cashierState.clearCart();
                              },
                        icon: const Icon(Icons.point_of_sale, size: 20),
                        label: const Text('Режим продажи'),
                      )
                    : OutlinedButton.icon(
                        onPressed: _isSelling ? null : () {
                          setState(() {
                            _isReturnMode = true;
                            _error = null;
                          });
                          _cashierState.clearCart();
                        },
                        icon: const Icon(Icons.keyboard_return, size: 20),
                        label: const Text('Режим возврата'),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
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
            ],
          ),
        ),
        if (_isReturnMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.accent.withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(Icons.keyboard_return, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Режим возврата — товары пополнят остатки',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        if (_error != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.danger.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.danger),
                  ),
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
              if (!_isReturnMode) ...[
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
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_cashierState.cart.isNotEmpty)
                Row(
                  children: [
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
                  _isReturnMode
                      ? FilledButton.icon(
                          onPressed: _isAcceptingReturn ||
                                  _cashierState.cart.isEmpty
                              ? null
                              : _acceptReturn,
                          icon: _isAcceptingReturn
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.keyboard_return, size: 20),
                          label: Text(
                            _isAcceptingReturn ? 'Приём...' : 'Принять возврат',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                        )
                      : FilledButton(
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
    ),
    if (_isSavingReceiptPdf) ...[
      ModalBarrier(dismissible: false),
      const Center(child: CircularProgressIndicator()),
    ],
  ],
    );
  }
}
