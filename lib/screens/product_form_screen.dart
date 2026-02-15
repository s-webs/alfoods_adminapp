import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/barcode_generator.dart';
import '../utils/toast.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.productId,
    this.mode = ProductFormMode.create,
    this.initialBarcode,
  });

  final Storage storage;
  final ApiService apiService;
  final int? productId;
  final ProductFormMode mode;
  /// Предзаполнение штрихкода (например, после сканирования при ненайденном товаре).
  final String? initialBarcode;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

enum ProductFormMode { create, edit }

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _stockThresholdController = TextEditingController();
  final _barcodeController = TextEditingController();

  Product? _product;
  List<Category> _categories = [];
  int? _selectedCategoryId;
  String _selectedUnit = 'pcs';
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  static const List<String> _units = ['pcs', 'g'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _stockThresholdController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await widget.apiService.getCategories();
      if (!mounted) return;
      setState(() => _categories = categories);

      if (widget.mode == ProductFormMode.edit && widget.productId != null) {
        final p = await widget.apiService.getProduct(widget.productId!);
        if (!mounted) return;
        setState(() {
          _product = p;
          _nameController.text = p.name;
          _priceController.text = p.price.toString();
          _discountPriceController.text = p.discountPrice?.toString() ?? '';
          _purchasePriceController.text = p.purchasePrice.toString();
          _stockController.text = p.stock.toString();
          _stockThresholdController.text = p.stockThreshold.toString();
          _barcodeController.text = p.barcode ?? '';
          _selectedCategoryId = p.categoryId;
          _selectedUnit = p.unit;
          _isActive = p.isActive;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
            _barcodeController.text = widget.initialBarcode!;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить данные';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text);
    if (name.isEmpty) return;
    if (price == null || price < 0) {
      showToast(context, 'Введите корректную цену');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': name,
        'category_id': _selectedCategoryId,
        'unit': _selectedUnit,
        'price': price,
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0,
        'barcode': _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        'stock': double.tryParse(_stockController.text) ?? 0,
        'stock_threshold': double.tryParse(_stockThresholdController.text) ?? 0,
        'is_active': _isActive,
      };
      final dp = double.tryParse(_discountPriceController.text);
      if (dp != null && dp > 0) {
        data['discount_price'] = dp;
      }
      if (widget.mode == ProductFormMode.edit && widget.productId != null) {
        await widget.apiService.updateProduct(widget.productId!, data);
      } else {
        await widget.apiService.createProduct(data);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().contains('422')
            ? 'Ошибка валидации'
            : 'Не удалось сохранить';
      });
    }
  }

  Future<void> _delete() async {
    if (widget.productId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text(
          'Товар «${_product?.name ?? ''}» будет удалён безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.apiService.deleteProduct(widget.productId!);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Не удалось удалить';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Товар')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null &&
        _product == null &&
        widget.mode == ProductFormMode.edit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Товар')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == ProductFormMode.edit
              ? 'Редактирование'
              : 'Новый товар',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<int?>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Без категории'),
                  ),
                  ..._categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Введите название',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Обязательное поле'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Единица'),
                items: _units
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(u == 'pcs' ? 'шт.' : 'г'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedUnit = v ?? 'pcs'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Цена',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (double.tryParse(v) == null || double.parse(v) < 0) {
                    return 'Введите корректную цену';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _discountPriceController,
                decoration: const InputDecoration(
                  labelText: 'Цена со скидкой',
                  hintText: '0.00 (необязательно)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(
                  labelText: 'Стоимость закупа',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Остаток',
                  hintText: '0',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockThresholdController,
                decoration: const InputDecoration(
                  labelText: 'Порог остатков',
                  hintText: '0',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Штрихкод',
                        hintText: '(необязательно)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        _barcodeController.text = generateBarcode();
                      },
                      child: const Text('Сгенерировать штрихкод'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Активен'),
                  const SizedBox(width: 12),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              ),
              if (widget.mode == ProductFormMode.edit) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSaving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: const Text('Удалить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
