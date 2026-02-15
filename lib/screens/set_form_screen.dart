import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../models/product_set.dart';
import '../services/api_service.dart';
import '../utils/barcode_generator.dart';
import '../utils/toast.dart';
import '../widgets/add_product_to_set_dialog.dart';

class SetFormScreen extends StatefulWidget {
  const SetFormScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.setId,
    this.mode = SetFormMode.create,
  });

  final Storage storage;
  final ApiService apiService;
  final int? setId;
  final SetFormMode mode;

  @override
  State<SetFormScreen> createState() => _SetFormScreenState();
}

enum SetFormMode { create, edit }

class _SetItem {
  _SetItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  final int productId;
  final String productName;
  double quantity;
}

class _SetFormScreenState extends State<SetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _barcodeController = TextEditingController();

  ProductSet? _set;
  List<_SetItem> _items = [];
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

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
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (widget.mode == SetFormMode.edit && widget.setId != null) {
        final s = await widget.apiService.getSet(widget.setId!);
        if (!mounted) return;
        setState(() {
          _set = s;
          _nameController.text = s.name;
          _priceController.text = s.price.toString();
          _discountPriceController.text = s.discountPrice?.toString() ?? '';
          _barcodeController.text = s.barcode ?? '';
          _isActive = s.isActive;
          _items = s.items
              .map(
                (i) => _SetItem(
                  productId: i.productId,
                  productName: i.product?.name ?? 'ID:${i.productId}',
                  quantity: i.quantity,
                ),
              )
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить данные';
        _isLoading = false;
      });
    }
  }

  Future<void> _addProduct() async {
    final result = await showDialog<AddProductToSetResult>(
      context: context,
      builder: (ctx) => AddProductToSetDialog(
        apiService: widget.apiService,
        excludedProductIds: {},
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final existing = _items.indexWhere(
          (i) => i.productId == result.product.id,
        );
        if (existing >= 0) {
          _items[existing].quantity += result.quantity;
        } else {
          _items.add(
            _SetItem(
              productId: result.product.id,
              productName: result.product.name,
              quantity: result.quantity,
            ),
          );
        }
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  List<Map<String, dynamic>> _mergeItemsByProductId() {
    final map = <int, double>{};
    for (final item in _items) {
      map[item.productId] = (map[item.productId] ?? 0) + item.quantity;
    }
    return map.entries
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();
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
    if (_items.isEmpty) {
      showToast(context, 'Добавьте хотя бы один товар в сет');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': name,
        'price': price,
        'barcode': _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        'is_active': _isActive,
        'items': _mergeItemsByProductId(),
      };
      final dp = double.tryParse(_discountPriceController.text);
      if (dp != null && dp > 0) {
        data['discount_price'] = dp;
      }
      if (widget.mode == SetFormMode.edit && widget.setId != null) {
        await widget.apiService.updateSet(widget.setId!, data);
      } else {
        await widget.apiService.createSet(data);
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
    if (widget.setId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сет?'),
        content: Text('Сет «${_set?.name ?? ''}» будет удалён безвозвратно.'),
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
      await widget.apiService.deleteSet(widget.setId!);
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
        appBar: AppBar(title: const Text('Сет')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _set == null && widget.mode == SetFormMode.edit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Сет')),
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
          widget.mode == SetFormMode.edit ? 'Редактирование сета' : 'Новый сет',
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
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        _barcodeController.text = generateBarcode();
                      },
                      child: const Text('Сгенерировать'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Состав сета',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить товар'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.muted.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Нет товаров в сете',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else
                ..._items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '× ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)}',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.danger,
                        ),
                        onPressed: () => _removeItem(i),
                      ),
                    ),
                  );
                }),
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
              if (widget.mode == SetFormMode.edit) ...[
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
