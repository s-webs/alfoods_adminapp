import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../utils/toast.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/waybill_analysis_dialog.dart';
import 'barcode_scanner_screen.dart';

class ProductReceiptFormScreen extends StatefulWidget {
  const ProductReceiptFormScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<ProductReceiptFormScreen> createState() =>
      _ProductReceiptFormScreenState();
}

class _ProductReceiptFormScreenState extends State<ProductReceiptFormScreen> {
  final List<CartItem> _items = [];
  List<Supplier> _suppliers = [];
  int? _selectedSupplierId;
  final TextEditingController _supplierNameController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final TextEditingController _barcodeController = TextEditingController();
  int? _editingPriceIndex;
  TextEditingController? _priceEditController;
  bool _isSaving = false;
  bool _isBarcodeLoading = false;
  bool _isUploadingImages = false;
  bool _isAnalyzingWaybill = false;
  final List<String> _images = [];
  final List<String> _localImagePaths = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeFocusNode.dispose();
    _barcodeController.dispose();
    _supplierNameController.dispose();
    _priceEditController?.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _error = null;
    });
    try {
      final suppliers = await widget.apiService.getSuppliers();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить поставщиков';
      });
    }
  }

  Future<void> _onBarcodeSubmitted(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty) return;
    _barcodeController.clear();
    if (_isBarcodeLoading || !mounted) return;
    setState(() => _isBarcodeLoading = true);
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
          showToast(context, 'Сеты не поддерживаются в поступлениях');
        } else {
          showToast(context, 'Товар с штрихкодом "$barcode" не найден');
        }
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Ошибка поиска товара');
      }
    } finally {
      if (mounted) setState(() => _isBarcodeLoading = false);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _barcodeFocusNode.canRequestFocus) {
            _barcodeFocusNode.requestFocus();
          }
        });
      }
    }
  }

  void _addProduct(Product product) {
    setState(() {
      final existingIndex = _items.indexWhere((item) => item.productId == product.id);
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += product.unit == 'pcs' ? 1.0 : 0.1;
      } else {
        _items.insert(0, CartItem(
          productId: product.id,
          name: product.name,
          price: product.purchasePrice,
          quantity: 1,
          unit: product.unit,
        ));
      }
    });
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      await _onBarcodeSubmitted(result.trim());
    }
  }

  Future<void> _showAddProductDialog() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) => AddProductDialog(apiService: widget.apiService),
    );
    if (result != null && mounted) {
      if (result is Product) {
        _addProduct(result);
      }
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _barcodeFocusNode.canRequestFocus) {
          _barcodeFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      showToast(context, 'Добавьте хотя бы одну позицию');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final receipt = await widget.apiService.createProductReceipt(
        supplierId: _selectedSupplierId,
        supplierName: _selectedSupplierId == null && _supplierNameController.text.isNotEmpty
            ? _supplierNameController.text.trim()
            : null,
        items: _items.map((e) => e.toJson()).toList(),
        images: _images,
      );
      if (!mounted) return;
      showToast(context, 'Поступление создано');
      context.go('/product-receipts/${receipt.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Не удалось сохранить поступление';
      });
      showToast(context, _error ?? 'Ошибка');
    }
  }

  Future<void> _pickAndUploadImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _isUploadingImages = true);
    try {
      for (final f in result.files) {
        if (f.path == null || f.path!.isEmpty) continue;
        final uploadedPath = await widget.apiService.uploadReceiptImage(
          f.path!,
          filename: f.name,
        );
        if (!mounted) return;
        setState(() {
          _images.add(uploadedPath);
          _localImagePaths.add(f.path!);
        });
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка загрузки изображений: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _captureAndUploadImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImages = true);
    try {
      final uploadedPath = await widget.apiService.uploadReceiptImage(
        picked.path,
        filename: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _images.add(uploadedPath);
        _localImagePaths.add(picked.path);
      });
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка загрузки фото: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (index < _localImagePaths.length) {
        _localImagePaths.removeAt(index);
      }
    });
  }

  Future<void> _analyzeWaybill() async {
    if (_localImagePaths.isEmpty) {
      showToast(context, 'Сначала загрузите фото накладной');
      return;
    }

    setState(() => _isAnalyzingWaybill = true);
    try {
      final result = await widget.apiService.analyzeWaybill(_localImagePaths.last);
      if (!mounted) return;
      if (result.items.isEmpty) {
        showToast(context, 'ИИ не распознал товары');
        return;
      }

      final futures = await Future.wait([
        widget.apiService.getProducts(active: true),
        widget.apiService.getWaybillMappings(),
      ]);
      final allProducts = futures[0] as List<Product>;
      final mappings = futures[1] as Map<String, int>;
      final byId = {for (final p in allProducts) p.id: p};
      if (!mounted) return;

      final resolved = <ResolvedWaybillItem>[];
      for (final aiItem in result.items) {
        Product? product;
        final aiName = aiItem.name;
        if (aiName != null && mappings.containsKey(aiName)) {
          product = byId[mappings[aiName]];
        }
        if (product == null && aiItem.barcode != null && aiItem.barcode!.isNotEmpty) {
          final matches = allProducts.where((p) => p.barcode == aiItem.barcode);
          if (matches.isNotEmpty) {
            product = matches.first;
          }
        }
        resolved.add(ResolvedWaybillItem(aiItem: aiItem, product: product));
      }

      final selected = await showDialog<List<ResolvedWaybillItem>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WaybillAnalysisDialog(
          result: result,
          resolvedItems: resolved,
          allProducts: allProducts,
          apiService: widget.apiService,
        ),
      );
      if (!mounted || selected == null || selected.isEmpty) return;

      var added = 0;
      for (final item in selected) {
        if (item.product == null) continue;
        final product = item.product!;
        final existingIndex = _items.indexWhere((e) => e.productId == product.id);
        final quantity = item.importQuantity ?? (product.unit == 'pcs' ? 1.0 : 0.1);
        final price = item.importPrice ?? product.purchasePrice;

        setState(() {
          if (existingIndex >= 0) {
            _items[existingIndex].quantity += quantity;
            _items[existingIndex].price = price;
          } else {
            _items.insert(
              0,
              CartItem(
                productId: product.id,
                name: product.name,
                price: price,
                quantity: quantity,
                unit: product.unit,
              ),
            );
            added++;
          }
        });
      }

      showToast(context, added > 0 ? 'Импортировано позиций: $added' : 'Позиции обновлены');
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка анализа накладной: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingWaybill = false);
    }
  }

  double get _itemsTotal =>
      _items.fold(0, (sum, item) => sum + item.total);

  void _updateQuantity(int index, double delta) {
    setState(() {
      final item = _items[index];
      final step = item.unit == 'pcs' ? 1.0 : 0.1;
      item.quantity += delta * step;
      if (item.quantity <= 0) {
        _items.removeAt(index);
      }
    });
  }

  Future<void> _editQuantity(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final isPcs = item.unit == 'pcs';
    final initial = isPcs
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);

    final controller = TextEditingController(text: initial);
    double? parseQuantity() {
      final v = double.tryParse(
        controller.text.replaceFirst(',', '.').trim(),
      );
      if (v == null || v < 0) return null;
      if (isPcs) return v.roundToDouble();
      return v; // граммовые: любое число (0.15, 0.25 и т.д.)
    }

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Количество: ${item.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isPcs ? 'Штук' : 'Кг (0.1 = 100 г)',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final v = parseQuantity();
              if (v != null) Navigator.of(ctx).pop(v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final v = parseQuantity();
                if (v != null) Navigator.of(ctx).pop(v);
              },
              child: const Text('Ок'),
            ),
          ],
        );
      },
    );
    if (result != null && mounted) {
      setState(() {
        if (result <= 0) {
          _items.removeAt(index);
        } else {
          _items[index].quantity = result;
        }
      });
    }
  }

  void _startEditPrice(int index) {
    if (index < 0 || index >= _items.length) return;
    setState(() {
      _editingPriceIndex = index;
      _priceEditController?.dispose();
      _priceEditController = TextEditingController(
        text: _items[index].price.toStringAsFixed(2),
      );
    });
  }

  void _finishEditPrice({bool save = true}) {
    final index = _editingPriceIndex;
    if (index == null || index < 0 || index >= _items.length) return;
    final controller = _priceEditController;
    if (controller != null && save) {
      final text = controller.text.replaceFirst(',', '.').trim();
      final value = double.tryParse(text);
      if (value != null && value >= 0) {
        setState(() {
          _items[index].price = value;
        });
      }
    }
    _priceEditController?.dispose();
    _priceEditController = null;
    _editingPriceIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Новое поступление'),
            actions: [
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _save,
                ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int?>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'Поставщик',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Не выбран')),
                        ..._suppliers.map(
                          (supplier) => DropdownMenuItem<int?>(
                            value: supplier.id,
                            child: Text(supplier.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplierId = value;
                          if (value != null) {
                            _supplierNameController.clear();
                          }
                        });
                      },
                    ),
                    if (_selectedSupplierId == null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _supplierNameController,
                        decoration: const InputDecoration(
                          labelText: 'Название поставщика',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _showAddProductDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить товар вручную'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isBarcodeLoading ? null : _openBarcodeScanner,
                          icon: _isBarcodeLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(PhosphorIconsRegular.barcode),
                          tooltip: 'Сканировать штрихкод',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingImages ? null : _pickAndUploadImages,
                            icon: _isUploadingImages
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: const Text('Фото накладной'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _isUploadingImages ? null : _captureAndUploadImage,
                          icon: const Icon(Icons.photo_camera_outlined),
                          tooltip: 'Сфотографировать',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: (_isAnalyzingWaybill || _localImagePaths.isEmpty)
                                ? null
                                : _analyzeWaybill,
                            icon: _isAnalyzingWaybill
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Анализ ИИ'),
                          ),
                        ),
                      ],
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.apiService.fileUrl(_images[index]),
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: InkWell(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: AppColors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Отсканируйте штрихкод товара',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ..._items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _startEditPrice(index),
                                          child: (_editingPriceIndex == index &&
                                                  _priceEditController != null)
                                              ? SizedBox(
                                                  width: 100,
                                                  child: TextField(
                                                    controller: _priceEditController,
                                                    autofocus: true,
                                                    keyboardType: const TextInputType
                                                        .numberWithOptions(
                                                            decimal: true),
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      border: OutlineInputBorder(),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4),
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
                                              fontWeight: FontWeight.w600),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () =>
                                              _updateQuantity(index, -1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () =>
                                              _updateQuantity(index, 1),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          color: AppColors.danger,
                                          onPressed: () {
                                            setState(() {
                                              _items.removeAt(index);
                                            });
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Итого:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${_itemsTotal.toStringAsFixed(2)} ₸',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              enabled: !_isBarcodeLoading,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: _onBarcodeSubmitted,
            ),
          ),
        ),
      ],
    );
  }
}
