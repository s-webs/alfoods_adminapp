import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/product_set.dart';
import '../services/api_service.dart';
import '../utils/toast.dart';

class SetsScreen extends StatefulWidget {
  const SetsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<SetsScreen> createState() => _SetsScreenState();
}

enum _SetsSortKey { id, name, price }

class _SetsScreenState extends State<SetsScreen> {
  List<ProductSet> _sets = [];
  String _searchQuery = '';
  bool _isLoading = true;
  int? _togglingActiveSetId;
  String? _error;
  _SetsSortKey _sortKey = _SetsSortKey.id;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final list = await widget.apiService.getSets();
      if (!mounted) return;
      setState(() {
        _sets = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить сеты';
        _isLoading = false;
      });
    }
  }

  int _compareSets(ProductSet a, ProductSet b) {
    int cmp;
    switch (_sortKey) {
      case _SetsSortKey.id:
        cmp = a.id.compareTo(b.id);
        break;
      case _SetsSortKey.name:
        cmp = a.name.compareTo(b.name);
        break;
      case _SetsSortKey.price:
        cmp = a.price.compareTo(b.price);
        break;
    }
    return _sortAsc ? cmp : -cmp;
  }

  String _itemsSummary(ProductSet s) {
    if (s.items.isEmpty) return '—';
    return s.items
        .map((i) =>
            '${i.product?.name ?? 'ID:${i.productId}'} × ${i.quantity.toStringAsFixed(i.quantity == i.quantity.roundToDouble() ? 0 : 2)}')
        .join(', ');
  }

  Future<void> _toggleSetActive(ProductSet s) async {
    setState(() => _togglingActiveSetId = s.id);
    try {
      await widget.apiService.updateSet(s.id, {'is_active': !s.isActive});
      if (!mounted) return;
      _load(silent: true);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Ошибка: $e');
      }
    } finally {
      if (mounted) setState(() => _togglingActiveSetId = null);
    }
  }

  Future<void> _deleteSet(ProductSet s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сет?'),
        content: Text('Сет «${s.name}» будет удалён безвозвратно.'),
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
    try {
      await widget.apiService.deleteSet(s.id);
      if (!mounted) return;
      _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось удалить');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final visibleSets = query.isEmpty
        ? _sets
        : _sets.where((s) {
            final idStr = s.id.toString();
            final name = s.name.toLowerCase();
            final barcode = (s.barcode ?? '').toLowerCase();
            return idStr.contains(query) ||
                name.contains(query) ||
                barcode.contains(query);
          }).toList();
    final sortedSets = List<ProductSet>.from(visibleSets)..sort(_compareSets);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Сеты',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await context.push<bool>('/sets/create');
                      if (result == true && mounted) _load(silent: true);
                    },
                    icon: const Icon(PhosphorIconsRegular.plus, size: 20),
                    label: const Text('Добавить'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск (id, штрихкод, название)',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: AppColors.muted,
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
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
                            onPressed: _load,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : visibleSets.isEmpty
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
                                query.isEmpty ? 'Нет сетов' : 'Ничего не найдено',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(silent: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: sortedSets.length,
                            itemBuilder: (context, index) {
                              final s = sortedSets[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () async {
                                    final result = await context.push<bool>(
                                      '/sets/${s.id}/edit',
                                    );
                                    if (result == true && mounted) {
                                      _load(silent: true);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              '${s.price.toStringAsFixed(2)} ₸',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (s.discountPrice != null &&
                                            s.discountPrice! > 0) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Со скидкой: ${s.discountPrice!.toStringAsFixed(2)} ₸',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                        if (s.barcode != null &&
                                            s.barcode!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Штрихкод: ${s.barcode}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              'Активен',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _togglingActiveSetId == s.id
                                                ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : Switch(
                                                    value: s.isActive,
                                                    onChanged: (_) =>
                                                        _toggleSetActive(s),
                                                  ),
                                          ],
                                        ),
                                        if (s.items.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            _itemsSummary(s),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                PhosphorIconsRegular.pencilSimple,
                                              ),
                                              onPressed: () async {
                                                final result =
                                                    await context.push<bool>(
                                                  '/sets/${s.id}/edit',
                                                );
                                                if (result == true && mounted) {
                                                  _load(silent: true);
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                PhosphorIconsRegular.trash,
                                                color: AppColors.danger,
                                              ),
                                              onPressed: () => _deleteSet(s),
                                            ),
                                          ],
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
