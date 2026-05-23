import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/product_set.dart';
import '../models/sale_create_result.dart';
import '../models/sale_payment_method.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import '../services/api_webkassa_exception.dart';
import '../services/cashier_resolver_service.dart';
import '../services/checkout_service.dart';
import '../services/receipt_pdf_service.dart';
import '../state/cashier_state.dart';
import '../utils/toast.dart';
import '../utils/webkassa_error_display.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/credit_sale_dialog.dart';
import '../widgets/fiscal_receipt_dialog.dart';
import '../widgets/mixed_payment_dialog.dart';
import '../widgets/pos_payment_method_dialog.dart';
import '../widgets/receipt_qr_dialog.dart';
import '../widgets/static_qr_payment_dialog.dart';
import '../widgets/z_report_dialog.dart';
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
  List<Shift> _shifts = [];
  bool _isLoading = true;
  bool _isOpeningShift = false;
  bool _isClosingShift = false;
  bool _isSelling = false;
  bool _isPosPaying = false;
  bool _isPaying = false;
  bool _isResetting = false;
  String? _error;
  int? _editingPriceIndex;
  TextEditingController? _priceEditController;
  late final TextEditingController _customerXinController;
  late final CashierResolverService _cashierResolver;
  late final CheckoutService _checkoutService;
  int? _resolvedCashierId;
  String? _customerXinError;
  CashierState? _state;
  bool _listenerAdded = false;

  static const _invalidCustomerXin = '__invalid__';

  @override
  void initState() {
    super.initState();
    _customerXinController = TextEditingController();
    _cashierResolver = CashierResolverService(widget.storage);
    _checkoutService = CheckoutService(widget.apiService);
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
    _customerXinController.dispose();
    super.dispose();
  }

  Shift? get _currentOpenShift {
    for (final s in _shifts) {
      if (s.isOpen) return s;
    }
    return null;
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
      final cashierId = await _cashierResolver.resolveCashierId(
        widget.apiService,
      );
      if (!mounted) return;
      setState(() {
        _shifts = shifts;
        _resolvedCashierId = cashierId;
        _isLoading = false;
        _isOpeningShift = false;
        _isClosingShift = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить смены';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openShift() async {
    setState(() {
      _isOpeningShift = true;
      _error = null;
    });
    try {
      await widget.apiService.createShift();
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть смену';
        _isOpeningShift = false;
      });
    }
  }

  Future<void> _closeShift() async {
    final shift = _currentOpenShift;
    if (shift == null) return;
    final cashierId = _resolvedCashierId;
    if (cashierId == null) {
      showToast(context, 'Кассир не привязан к пользователю');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Закрыть смену?'),
        content: const Text(
          'Если за смену были ОФД-продажи, будет сформирован Z-отчёт в WebKassa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isClosingShift = true;
      _error = null;
    });
    try {
      final result =
          await widget.apiService.closeShift(shift.id, cashierId: cashierId);
      await _load();
      if (!mounted) return;
      setState(() => _isClosingShift = false);
      showToast(
        context,
        result.message ??
            (result.zReport != null
                ? 'Смена закрыта. Z-отчёт сформирован'
                : 'Смена закрыта'),
      );
      final zReport = result.shift.webkassaZReport ?? result.zReport;
      if (ZReportDialog.hasViewableData(zReport)) {
        await ZReportDialog.show(
          context,
          zReport: zReport!,
          zReportAt: result.shift.webkassaZReportAt,
        );
      }
    } on ApiWebkassaException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = formatWebkassaError(e);
        _isClosingShift = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось закрыть смену';
        _isClosingShift = false;
      });
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
        stock: product.stock,
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
    final initialName = barcode == 'manual' ? '' : 'Товар $barcode';
    final nameController = TextEditingController(text: initialName);
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
                  key: ValueKey(unit),
                  initialValue: unit,
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

  Future<void> _addOneOffItem() async {
    await _showAddSnapshotToCartDialog('manual');
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

  Future<void> _showWebkassaCheckoutError(ApiWebkassaException e) async {
    setState(() => _error = formatWebkassaError(e));
    final hint = webkassaErrorHint(e.webkassaCode);
    if (hint != null) showToast(context, hint);
    if (e.fiscal != null) {
      await FiscalReceiptDialog.show(context, fiscal: e.fiscal!);
    }
  }

  String? _readCustomerXinForCheckout() {
    final raw = _customerXinController.text.trim();
    if (raw.isEmpty) {
      setState(() => _customerXinError = null);
      return null;
    }
    if (RegExp(r'^\d{12}$').hasMatch(raw)) {
      setState(() => _customerXinError = null);
      return raw;
    }
    setState(() => _customerXinError = 'ИИН/БИН: ровно 12 цифр');
    showToast(context, 'ИИН/БИН: ровно 12 цифр');
    return _invalidCustomerXin;
  }

  void _clearFiscalCheckoutFields() {
    _customerXinController.clear();
    if (_customerXinError != null && mounted) {
      setState(() => _customerXinError = null);
    }
  }

  bool _validateCheckoutPreconditions({bool requireCashier = false}) {
    if (_cashierState.cart.isEmpty) {
      showToast(context, 'Корзина пуста');
      return false;
    }
    if (_currentOpenShift == null) {
      showToast(context, 'Смена не открыта');
      return false;
    }
    if (requireCashier && _resolvedCashierId == null) {
      showToast(
        context,
        'Нет привязки кассира к пользователю для WebKassa',
      );
      return false;
    }
    return true;
  }

  Future<void> _showOfdReceiptQr(SaleCreateResult result) async {
    if (!mounted) return;
    final url = result.fiscal?.ticketUrl ?? result.sale.ticketUrl;
    if (url == null || url.isEmpty) {
      showToast(context, 'Продажа оформлена');
      return;
    }
    await ReceiptQrDialog.show(
      context,
      url: url,
      title: 'Чек WebKassa',
      hint: 'Отсканируйте QR для открытия фискального чека',
    );
  }

  Future<String> _cashierDisplayName() async {
    if (_resolvedCashierId == null) return 'Касса';
    try {
      final cashiers = await widget.apiService.getCashiers();
      for (final c in cashiers) {
        if (c.id == _resolvedCashierId) return c.name;
      }
    } catch (_) {}
    return 'Касса';
  }

  Future<void> _showInternalReceiptQr({
    required int saleId,
    required List<CartItem> items,
    required double total,
  }) async {
    if (!mounted) return;
    try {
      final cashierName = await _cashierDisplayName();
      final pdfBytes = await ReceiptPdfService.buildReceiptPdf(
        saleId: saleId,
        cashierName: cashierName,
        items: items,
        total: total,
        dateTime: DateTime.now(),
      );
      final upload = await widget.apiService.uploadPdf(
        pdfBytes,
        'chek-$saleId.pdf',
      );
      if (!mounted) return;
      await ReceiptQrDialog.show(
        context,
        url: upload.url,
        title: 'Товарный чек',
        hint: 'Отсканируйте QR для открытия товарного чека',
      );
    } catch (_) {
      if (mounted) {
        showToast(context, 'Продажа #$saleId оформлена');
      }
    }
  }

  Future<bool> _confirmStaticQrPayments(
    List<({SalePaymentMethod method, double amount})> lines,
  ) async {
    for (final line in lines) {
      if (!line.method.isStaticQrPayment) continue;
      final ok = await StaticQrPaymentDialog.show(
        context,
        method: line.method,
        amount: line.amount,
      );
      if (!ok || !mounted) return false;
    }
    return true;
  }

  Future<void> _openPosPayment() async {
    if (!_validateCheckoutPreconditions(requireCashier: true)) return;
    final method = await PosPaymentMethodDialog.show(context);
    if (method == null || !mounted) return;
    if (method.isStaticQrPayment) {
      final ok = await StaticQrPaymentDialog.show(
        context,
        method: method,
        amount: _cashierState.cartTotal,
      );
      if (!ok || !mounted) return;
    }
    final customerXin = _readCustomerXinForCheckout();
    if (customerXin == _invalidCustomerXin) return;
    await _checkoutOfdDirect(method, customerXin: customerXin);
  }

  Future<void> _checkoutOfdDirect(
    SalePaymentMethod method, {
    String? customerXin,
  }) async {
    final shift = _currentOpenShift!;
    setState(() {
      _isPosPaying = true;
      _error = null;
    });
    try {
      final result = await _checkoutService.finalizeOfdSale(
        cashierId: _resolvedCashierId!,
        shiftId: shift.id,
        items: _cashierState.cart.map((c) => c.toJson()).toList(),
        paymentMethod: method,
        customerXin: customerXin,
      );
      if (!mounted) return;
      _clearFiscalCheckoutFields();
      _cashierState.clearCart();
      await _showOfdReceiptQr(result);
    } on ApiWebkassaException catch (e) {
      if (!mounted) return;
      await _showWebkassaCheckoutError(e);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось оформить продажу');
    } finally {
      if (mounted) setState(() => _isPosPaying = false);
    }
  }

  Future<void> _openMixedPayment() async {
    if (!_validateCheckoutPreconditions(requireCashier: true)) return;
    final splits = await MixedPaymentDialog.show(
      context,
      totalAmount: _cashierState.cartTotal,
    );
    if (splits == null || !mounted) return;
    final qrLines = splits
        .where((s) => s.method.isStaticQrPayment)
        .map((s) => (method: s.method, amount: s.amount))
        .toList();
    if (qrLines.isNotEmpty) {
      final confirmed = await _confirmStaticQrPayments(qrLines);
      if (!confirmed || !mounted) return;
    }
    final customerXin = _readCustomerXinForCheckout();
    if (customerXin == _invalidCustomerXin) return;
    final shift = _currentOpenShift!;
    setState(() {
      _isPosPaying = true;
      _error = null;
    });
    try {
      final result = await _checkoutService.finalizeMixedOfdSale(
        cashierId: _resolvedCashierId!,
        shiftId: shift.id,
        items: _cashierState.cart.map((c) => c.toJson()).toList(),
        paymentSplits: splits,
        customerXin: customerXin,
      );
      if (!mounted) return;
      _clearFiscalCheckoutFields();
      _cashierState.clearCart();
      await _showOfdReceiptQr(result);
    } on ApiWebkassaException catch (e) {
      if (!mounted) return;
      await _showWebkassaCheckoutError(e);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось оформить смешанную оплату');
    } finally {
      if (mounted) setState(() => _isPosPaying = false);
    }
  }

  Future<void> _payWithoutOfd() async {
    await _completeNonOfdCheckout(SalePaymentMethod.payment);
  }

  Future<void> _completeNonOfdCheckout(SalePaymentMethod method) async {
    if (!_validateCheckoutPreconditions()) return;
    final shift = _currentOpenShift!;
    setState(() {
      _isPaying = method == SalePaymentMethod.payment;
      _isSelling = method != SalePaymentMethod.payment;
      _error = null;
    });
    final cartItems = List<CartItem>.from(_cashierState.cart);
    final cartTotal = _cashierState.cartTotal;
    final items = cartItems.map((c) => c.toJson()).toList();
    try {
      final result = await _checkoutService.finalizeNonOfdSale(
        cashierId: _resolvedCashierId,
        shiftId: shift.id,
        items: items,
        paymentMethod: method,
      );
      if (!mounted) return;
      _clearFiscalCheckoutFields();
      _cashierState.clearCart();
      if (method == SalePaymentMethod.payment) {
        await _showInternalReceiptQr(
          saleId: result.sale.id,
          items: cartItems,
          total: cartTotal,
        );
      } else {
        showToast(context, 'Продажа #${result.sale.id} оформлена');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось оформить продажу');
      showToast(
        context,
        'Ошибка: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _isSelling = false;
        });
      }
    }
  }

  Future<void> _sellOnCredit() async {
    if (_cashierState.cart.isEmpty) {
      showToast(context, 'Корзина пуста');
      return;
    }
    final shift = _currentOpenShift;
    if (shift == null) {
      showToast(context, 'Смена не открыта');
      return;
    }
    final creditResult = await showDialog<CreditSaleResult>(
      context: context,
      builder: (ctx) => CreditSaleDialog(apiService: widget.apiService),
    );
    if (creditResult == null ||
        !creditResult.isOnCredit ||
        creditResult.counterpartyId == null) {
      return;
    }
    setState(() {
      _isSelling = true;
      _error = null;
    });
    try {
      final result = await widget.apiService.createSale(
        shiftId: shift.id,
        cashierId: _resolvedCashierId,
        counterpartyId: creditResult.counterpartyId,
        isOnCredit: true,
        items: _cashierState.cart.map((c) => c.toJson()).toList(),
      );
      if (!mounted) return;
      _clearFiscalCheckoutFields();
      _cashierState.clearCart();
      setState(() => _isSelling = false);
      showToast(context, 'Продажа в долг #${result.sale.id} оформлена');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось оформить продажу в долг';
        _isSelling = false;
      });
    }
  }

  Widget _buildShiftBlock() {
    final open = _currentOpenShift;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: open != null
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.muted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              open != null
                  ? 'Смена #${open.id} открыта'
                  : 'Смена не открыта',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (open == null)
            FilledButton(
              onPressed: _isOpeningShift ? null : _openShift,
              child: _isOpeningShift
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Открыть'),
            )
          else
            OutlinedButton(
              onPressed: _isClosingShift ? null : _closeShift,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              child: _isClosingShift
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Закрыть смену'),
            ),
        ],
      ),
    );
  }

  String _formatCartTotalQty(double qty) {
    final rounded = qty.roundToDouble();
    if ((qty - rounded).abs() < 1e-9) return rounded.toInt().toString();
    final s = qty.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static const _checkoutBtnRadius = BorderRadius.all(Radius.circular(8));

  ButtonStyle _compactOutlinedStyle(Color fg) {
    return OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: BorderSide(color: fg.withValues(alpha: 0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      minimumSize: const Size(0, 38),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: const RoundedRectangleBorder(borderRadius: _checkoutBtnRadius),
    );
  }

  Widget _compactOutlinedBtn({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: _compactOutlinedStyle(color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildResetCartButton({required bool enabled}) {
    return Tooltip(
      message: 'Сброс',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _resetCart : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.danger.withValues(
                  alpha: enabled ? 0.6 : 0.25,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: _isResetting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.clear_all,
                    size: 20,
                    color: enabled
                        ? AppColors.danger
                        : AppColors.danger.withValues(alpha: 0.35),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _compactSellBtn({required VoidCallback? onPressed}) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF43A047),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: const RoundedRectangleBorder(borderRadius: _checkoutBtnRadius),
      ),
      child: _isPaying
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart_checkout, size: 22),
                SizedBox(height: 1),
                Text(
                  'Продать',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }

  Widget _buildCheckoutActions() {
    final cartNotEmpty = _cashierState.cart.isNotEmpty;
    final shiftOpen = _currentOpenShift != null;
    final isCheckoutBlocking = _isSelling || _isPosPaying || _isPaying;
    final isPosCheckoutEnabled = cartNotEmpty && shiftOpen && !isCheckoutBlocking;
    final isNonOfdCheckoutEnabled =
        cartNotEmpty && shiftOpen && !isCheckoutBlocking;
    final isCreditSaleEnabled =
        cartNotEmpty && shiftOpen && !isCheckoutBlocking;
    final totalQty = _cashierState.cart.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final itemCount = _cashierState.cart.length;
    final totalStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: cartNotEmpty ? AppColors.primary : AppColors.muted,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_cashierState.cartTotal.toStringAsFixed(2)} ₸',
                    style: totalStyle,
                  ),
                  if (cartNotEmpty)
                    Text(
                      '$itemCount поз. · ${_formatCartTotalQty(totalQty)} шт.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                ],
              ),
            ),
            _buildResetCartButton(
              enabled: cartNotEmpty && !_isResetting && !isCheckoutBlocking,
            ),
          ],
        ),
        if (cartNotEmpty && !shiftOpen) ...[
          const SizedBox(height: 4),
          Text(
            'Откройте смену для продажи',
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 6,
          childAspectRatio: 2.35,
          children: [
            _compactOutlinedBtn(
              onPressed: isPosCheckoutEnabled ? _openPosPayment : null,
              icon: Icons.point_of_sale,
              label: 'POS Оплата',
              color: AppColors.primary,
            ),
            _compactOutlinedBtn(
              onPressed: isPosCheckoutEnabled ? _openMixedPayment : null,
              icon: Icons.account_balance_wallet_outlined,
              label: 'Смешанная оплата',
              color: AppColors.primary,
            ),
            _compactOutlinedBtn(
              onPressed: isCreditSaleEnabled ? _sellOnCredit : null,
              icon: Icons.credit_card,
              label: 'В долг',
              color: AppColors.danger,
            ),
            _compactSellBtn(
              onPressed: isNonOfdCheckoutEnabled ? _payWithoutOfd : null,
            ),
          ],
        ),
      ],
    );
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
              _buildShiftBlock(),
              if (_currentOpenShift != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customerXinController,
                  decoration: InputDecoration(
                    labelText: 'ИИН/БИН покупателя',
                    errorText: _customerXinError,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    onPressed: _openAddProductDialog,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Icon(PhosphorIconsRegular.plus, size: 20),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _addOneOffItem,
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text('Разовый товар'),
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
                                '${item.orderIndex}. ${item.name}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              if (item.productId != 0 && item.stock != null)
                                Text(
                                  'Остаток: ${item.stock!.toStringAsFixed(item.unit == 'pcs' ? 0 : 2)} ${item.unit}',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              if (item.productId != 0 && item.stock != null)
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
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: _buildCheckoutActions(),
          ),
        ),
      ],
    ),
        if (_isPosPaying || _isPaying)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isPaying
                              ? 'Подготовка чека…'
                              : 'Оформление продажи…',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
