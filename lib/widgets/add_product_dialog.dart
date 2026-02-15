import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../models/product_set.dart';
import '../services/api_service.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({
    super.key,
    required this.apiService,
    this.onAddProduct,
    this.onAddSet,
  });

  final ApiService apiService;
  /// При указании — товар добавляется через callback, диалог остаётся открытым.
  final void Function(Product)? onAddProduct;
  /// При указании — сет добавляется через callback, диалог остаётся открытым.
  final void Function(ProductSet)? onAddSet;

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog>
    with SingleTickerProviderStateMixin {
  List<Product> _products = [];
  List<ProductSet> _sets = [];
  List<ProductSet> _filteredSets = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingMoreProducts = false;
  String? _error;
  final _searchController = TextEditingController();
  late TabController _tabController;
  final ScrollController _productScrollController = ScrollController();
  Timer? _searchDebounce;
  int _productPage = 1;
  int _productTotal = 0;
  static const int _perPage = 20;

  bool get _hasMoreProducts =>
      (_productPage * _perPage) < _productTotal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _productScrollController.addListener(_onProductScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productScrollController.removeListener(_onProductScroll);
    _productScrollController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onProductScroll() {
    if (_isLoadingMoreProducts || !_hasMoreProducts) return;
    if (_products.length < _productTotal &&
        _productScrollController.position.pixels >=
            _productScrollController.position.maxScrollExtent - 100) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadProducts({bool reset = true}) async {
    if (reset) {
      setState(() {
        _products = [];
        _productPage = 1;
        _productTotal = 0;
      });
    }
    try {
      final result = await widget.apiService.getProductsPaginated(
        page: reset ? 1 : _productPage,
        perPage: _perPage,
        active: true,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );
      if (!mounted) return;
      setState(() {
        _products = reset ? result.data : [..._products, ...result.data];
        _productTotal = result.total;
        _productPage = result.currentPage;
      });
    } catch (_) {}
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMoreProducts || !_hasMoreProducts) return;
    setState(() => _isLoadingMoreProducts = true);
    try {
      final result = await widget.apiService.getProductsPaginated(
        page: _productPage + 1,
        perPage: _perPage,
        active: true,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...result.data];
        _productTotal = result.total;
        _productPage = result.currentPage;
        _isLoadingMoreProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreProducts = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiService.getSets(active: true),
        widget.apiService.getProductsPaginated(
          page: 1,
          perPage: _perPage,
          active: true,
          search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        ),
      ]);
      if (!mounted) return;
      final sets = results[0] as List<ProductSet>;
      final prodResult = results[1] as PaginatedProducts;
      final sortedSets =
          List<ProductSet>.from(sets)..sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _sets = sortedSets;
        _products = prodResult.data;
        _productTotal = prodResult.total;
        _productPage = prodResult.currentPage;
        _filterSets();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить данные';
        _isLoading = false;
      });
    }
  }

  void _filterSets() {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredSets = List.from(_sets);
    } else {
      _filteredSets =
          _sets.where((s) => s.name.toLowerCase().contains(query)).toList();
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _filterSets();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _loadProducts(reset: true),
    );
  }

  void _selectProduct(Product product) {
    if (widget.onAddProduct != null) {
      widget.onAddProduct!(product);
    } else {
      Navigator.pop(context, product);
    }
  }

  void _selectSet(ProductSet productSet) {
    if (widget.onAddSet != null) {
      widget.onAddSet!(productSet);
    } else {
      Navigator.pop(context, productSet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Поиск по названию...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: _onSearchChanged,
                      autofocus: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Товары'),
                Tab(text: 'Сеты'),
              ],
            ),
            const Divider(height: 1),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.danger,
                              ),
                              const SizedBox(height: 16),
                              Text(_error!),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProductList(),
                            _buildSetList(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (!_isLoading && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _productScrollController,
      shrinkWrap: true,
      itemCount: _products.length + (_isLoadingMoreProducts ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = _products[index];
        return ListTile(
          title: Text(p.name),
          subtitle: Text(
            '${p.effectivePrice.toStringAsFixed(2)} ₸ • ${p.unit}',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.add),
          onTap: () => _selectProduct(p),
        );
      },
    );
  }

  Widget _buildSetList() {
    if (_filteredSets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _filteredSets.length,
      itemBuilder: (context, index) {
        final s = _filteredSets[index];
        return ListTile(
          title: Text(s.name),
          subtitle: Text(
            '${s.effectivePrice.toStringAsFixed(2)} ₸ • шт',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.add),
          onTap: () => _selectSet(s),
        );
      },
    );
  }
}
