import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'barcode_scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  static const int _allCategoriesId = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
    if (result == null || !mounted) return;
    _searchController.text = result;
    setState(() => _searchQuery = result);
    final product = await widget.apiService.getProductByBarcode(result);
    if (!mounted) return;
    if (product != null) {
      context.go('/products/${product.id}/edit');
    } else {
      context.go('/products/create?barcode=${Uri.encodeComponent(result)}');
    }
  }

  static String _formatStock(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      final trimmed = s
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      return trimmed;
    }
    return s;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final products = await widget.apiService.getProducts(
        categoryId: _selectedCategoryId == _allCategoriesId
            ? null
            : _selectedCategoryId,
      );
      final categories = await widget.apiService.getCategories();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить товары';
        _isLoading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((p) {
      if (p.name.toLowerCase().contains(query)) return true;
      if (p.barcode != null && p.barcode!.toLowerCase().contains(query)) {
        return true;
      }
      if (p.id.toString().contains(query)) return true;
      return false;
    }).toList();
  }

  String _categoryName(int? categoryId) {
    if (categoryId == null) return '—';
    if (categoryId == _allCategoriesId) return 'Все';
    final c = _categories.where((x) => x.id == categoryId).firstOrNull;
    return c?.name ?? '—';
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
              bottom: BorderSide(
                color: AppColors.muted.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Товары',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.push('/products/create'),
                    icon: const Icon(PhosphorIconsRegular.plus, size: 20),
                    label: const Text('Добавить'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск (название, штрихкод, id)',
                        prefixIcon: Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          color: AppColors.muted,
                        ),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.barcode),
                    onPressed: _openBarcodeScanner,
                    tooltip: 'Сканировать штрихкод',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Все категории'),
                      selected: _selectedCategoryId == null ||
                          _selectedCategoryId == _allCategoriesId,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = _allCategoriesId);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._categories.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: _selectedCategoryId == c.id,
                          onSelected: (_) {
                            setState(() => _selectedCategoryId = c.id);
                            _load();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsRegular.warningCircle,
                            size: 48,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 16),
                          Text(_error!),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => _load(),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIconsRegular.package,
                                size: 64,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.trim().isEmpty
                                    ? 'Нет товаров'
                                    : 'Ничего не найдено',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final p = _filteredProducts[index];
                              final categoryName =
                                  _categoryName(p.categoryId);
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () =>
                                      context.push('/products/${p.id}/edit'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: p.isActive
                                                    ? AppColors.accent
                                                    : AppColors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${p.effectivePrice.toStringAsFixed(0)} ₸',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Остаток: ${_formatStock(p.stock)} ${p.unit == 'pcs' ? 'шт.' : 'кг'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          categoryName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
