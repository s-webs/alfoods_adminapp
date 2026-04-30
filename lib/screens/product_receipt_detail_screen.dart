import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/product_receipt.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../utils/toast.dart';
import '../widgets/add_product_dialog.dart';

class ProductReceiptDetailScreen extends StatefulWidget {
  const ProductReceiptDetailScreen({
    super.key,
    required this.apiService,
    required this.receiptId,
  });

  final ApiService apiService;
  final int receiptId;

  @override
  State<ProductReceiptDetailScreen> createState() =>
      _ProductReceiptDetailScreenState();
}

class _ProductReceiptDetailScreenState
    extends State<ProductReceiptDetailScreen> {
  ProductReceipt? _receipt;
  List<CartItem> _items = [];
  List<Supplier> _suppliers = [];
  int? _selectedSupplierId;
  String? _supplierName;
  int? _editingPriceIndex;
  TextEditingController? _priceEditController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImages = false;
  List<String> _images = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceEditController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final receipt = await widget.apiService.getProductReceipt(widget.receiptId);
      final suppliers = await widget.apiService.getSuppliers();
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _items = receipt.items
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
        _suppliers = suppliers;
        _selectedSupplierId = receipt.supplierId;
        _supplierName = receipt.supplierName;
        _images = List<String>.from(receipt.images);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить поступление';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_receipt == null) return;
    if (_items.isEmpty) {
      showToast(context, 'Добавьте хотя бы одну позицию');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.apiService.updateProductReceipt(
        widget.receiptId,
        supplierId: _selectedSupplierId,
        supplierName: _selectedSupplierId == null ? _supplierName : null,
        items: _items.map((e) => e.toJson()).toList(),
        images: _images,
      );
      if (!mounted) return;
      showToast(context, 'Поступление обновлено');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Не удалось сохранить';
      });
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

  Future<void> _showAddProductDialog() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) => AddProductDialog(apiService: widget.apiService),
    );
    if (result != null && mounted) {
      if (result is Product) {
        setState(() {
          _items.add(
            CartItem(
              productId: result.id,
              name: result.name,
              price: result.purchasePrice,
              quantity: 1,
              unit: result.unit,
            ),
          );
        });
      }
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
        final path = f.path;
        if (path == null || path.isEmpty) continue;
        final uploadedPath = await widget.apiService.uploadReceiptImage(
          path,
          filename: f.name,
        );
        if (!mounted) return;
        setState(() => _images.add(uploadedPath));
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка загрузки: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _showImagePreview(String path) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Накладная'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          body: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.network(
                widget.apiService.fileUrl(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Не удалось загрузить изображение',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _receipt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Поступление')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Ошибка', style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Поступление #${_receipt!.id}'),
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
                Text(
                  'Дата: ${_formatDate(_receipt!.createdAt)}',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
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
                        _supplierName = null;
                      }
                    });
                  },
                ),
                if (_selectedSupplierId == null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Название поставщика',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: _supplierName)
                      ..selection = TextSelection.collapsed(
                        offset: _supplierName?.length ?? 0,
                      ),
                    onChanged: (value) {
                      _supplierName = value.isEmpty ? null : value;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isUploadingImages ? null : _pickAndUploadImages,
                  icon: _isUploadingImages
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: const Text('Добавить фото накладной'),
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
                        final imagePath = _images[index];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _showImagePreview(imagePath),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.apiService.fileUrl(imagePath),
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                ),
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
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
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
            child: ListView(
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
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
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
                                          decoration: TextDecoration.underline,
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
                if (_items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Нет товаров',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
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
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить товар'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
