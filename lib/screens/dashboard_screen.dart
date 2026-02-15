import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/sale.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum DashboardPeriod {
  shift,
  week,
  month,
  custom,
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Shift> _shifts = [];
  List<Sale> _sales = [];
  bool _isLoading = true;
  String? _error;
  DashboardPeriod _period = DashboardPeriod.week;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _chartType = 0; // 0: line, 1: bar, 2: pie

  Shift? get _openShift =>
      _shifts.where((s) => s.isOpen).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final shifts = await widget.apiService.getShifts();
      final sales = await widget.apiService.getSales();
      if (!mounted) return;
      setState(() {
        _shifts = shifts;
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить данные';
        _isLoading = false;
      });
    }
  }

  List<Sale> get _filteredSales {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final openShift = _openShift;

    return _sales.where((s) {
      if (s.isReturned) return false;
      switch (_period) {
        case DashboardPeriod.shift:
          if (openShift == null) return false;
          return s.shiftId == openShift.id;
        case DashboardPeriod.week:
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
          final saleDate = s.createdAt;
          return !saleDate.isBefore(weekStart) && !saleDate.isAfter(weekEnd);
        case DashboardPeriod.month:
          return s.createdAt.year == now.year && s.createdAt.month == now.month;
        case DashboardPeriod.custom:
          if (_dateFrom == null || _dateTo == null) return false;
          final start = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
          final end = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
          return !s.createdAt.isBefore(start) && !s.createdAt.isAfter(end);
      }
    }).toList();
  }

  double get _totalAmount => _filteredSales.fold(0.0, (s, e) => s + e.totalPrice);
  double get _totalQuantity => _filteredSales.fold(0.0, (s, e) => s + e.totalQty);

  List<({String name, double qty})> get _topProducts {
    final map = <String, double>{};
    for (final sale in _filteredSales) {
      for (final item in sale.items) {
        map[item.name] = (map[item.name] ?? 0) + item.quantity;
      }
    }
    return map.entries
        .map((e) => (name: e.key, qty: e.value))
        .toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
  }

  Map<DateTime, double> get _salesByDay {
    final map = <DateTime, double>{};
    for (final sale in _filteredSales) {
      final day = DateTime(
        sale.createdAt.year,
        sale.createdAt.month,
        sale.createdAt.day,
      );
      map[day] = (map[day] ?? 0) + sale.totalPrice;
    }
    final keys = map.keys.toList()..sort();
    return Map.fromEntries(keys.map((k) => MapEntry(k, map[k]!)));
  }

  String _formatHoursElapsed(DateTime openedAt) {
    final now = DateTime.now();
    final diff = now.difference(openedAt);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return '$hours ч $minutes мин';
    }
    return '$minutes мин';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(_error!),
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

    final openShift = _openShift;
    final salesByDay = _salesByDay;
    final topProducts = _topProducts.take(5).toList();
    final popularProducts = _topProducts.take(10).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Дашборд',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Открытая смена',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (openShift != null) ...[
                        Text(
                          'Открыта: ${openShift.openedAt.day.toString().padLeft(2, '0')}.${openShift.openedAt.month.toString().padLeft(2, '0')}.${openShift.openedAt.year} '
                          '${openShift.openedAt.hour.toString().padLeft(2, '0')}:${openShift.openedAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Прошло: ${_formatHoursElapsed(openShift.openedAt)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ] else
                        Text(
                          'Нет открытой смены',
                          style: TextStyle(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Период',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Смена'),
                    selected: _period == DashboardPeriod.shift,
                    onSelected: (_) =>
                        setState(() => _period = DashboardPeriod.shift),
                  ),
                  FilterChip(
                    label: const Text('Неделя'),
                    selected: _period == DashboardPeriod.week,
                    onSelected: (_) =>
                        setState(() => _period = DashboardPeriod.week),
                  ),
                  FilterChip(
                    label: const Text('Месяц'),
                    selected: _period == DashboardPeriod.month,
                    onSelected: (_) =>
                        setState(() => _period = DashboardPeriod.month),
                  ),
                  FilterChip(
                    label: const Text('Даты'),
                    selected: _period == DashboardPeriod.custom,
                    onSelected: (_) => setState(() {
                          _period = DashboardPeriod.custom;
                          _dateFrom ??= DateTime.now();
                          _dateTo ??= DateTime.now();
                        }),
                  ),
                ],
              ),
              if (_period == DashboardPeriod.custom) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null && mounted) {
                            setState(() => _dateFrom = d);
                          }
                        },
                        child: Text(
                          _dateFrom != null
                              ? '${_dateFrom!.day.toString().padLeft(2, '0')}.${_dateFrom!.month.toString().padLeft(2, '0')}.${_dateFrom!.year}'
                              : 'От',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null && mounted) {
                            setState(() => _dateTo = d);
                          }
                        },
                        child: Text(
                          _dateTo != null
                              ? '${_dateTo!.day.toString().padLeft(2, '0')}.${_dateTo!.month.toString().padLeft(2, '0')}.${_dateTo!.year}'
                              : 'До',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.package,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Кол-во товаров',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalQuantity.toStringAsFixed(0),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.currencyCircleDollar,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Сумма, ₸',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalAmount.toStringAsFixed(0),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (topProducts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Топ товаров',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topProducts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = topProducts[i];
                      return ListTile(
                        title: Text(p.name),
                        trailing: Text(
                          p.qty.toStringAsFixed(p.qty == p.qty.roundToDouble() ? 0 : 2),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'График',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, icon: Icon(Icons.show_chart)),
                      ButtonSegment(value: 1, icon: Icon(Icons.bar_chart)),
                      ButtonSegment(value: 2, icon: Icon(Icons.pie_chart)),
                    ],
                    selected: {_chartType},
                    onSelectionChanged: (s) =>
                        setState(() => _chartType = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: salesByDay.isEmpty && popularProducts.isEmpty
                      ? const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'Нет данных за период',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (salesByDay.isNotEmpty) ...[
                              SizedBox(
                                height: 220,
                                child: _chartType == 0
                                    ? _buildLineChart(salesByDay)
                                    : _chartType == 1
                                        ? _buildBarChart(salesByDay)
                                        : _buildPieChart(salesByDay),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (popularProducts.isNotEmpty)
                              SizedBox(
                                height: _popularProductsChartHeight(popularProducts.length),
                                child: _buildPopularProductsChart(popularProducts),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<DateTime, double> dataByDay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Сумма продаж, ₸ по дням',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _lineChartWidget(dataByDay, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _lineChartWidget(Map<DateTime, double> dataByDay, {Color color = AppColors.primary}) {
    final spots = dataByDay.entries
        .toList()
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i >= 0 && i < dataByDay.length) {
                  final d = dataByDay.keys.elementAt(i);
                  return Text(
                    '${d.day}.${d.month}',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<DateTime, double> dataByDay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Сумма продаж, ₸ по дням',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _barChartWidget(dataByDay, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _barChartWidget(Map<DateTime, double> dataByDay, {Color color = AppColors.primary}) {
    final bars = dataByDay.entries.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (dataByDay.values.isEmpty ? 1 : dataByDay.values.reduce((a, b) => a > b ? a : b)) * 1.2,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i >= 0 && i < bars.length) {
                  final d = bars[i].key;
                  return Text(
                    '${d.day}.${d.month}',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: bars.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: color,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
            showingTooltipIndicators: [],
          );
        }).toList(),
      ),
    );
  }

  double _popularProductsChartHeight(int count) {
    return (count * 28.0) + 80;
  }

  Widget _buildPopularProductsChart(List<({String name, double qty})> products) {
    if (products.isEmpty) return const SizedBox();
    final maxQty = products.map((p) => p.qty).reduce((a, b) => a > b ? a : b);
    final colors = [
      AppColors.primary,
      AppColors.accent,
      Colors.orange,
      Colors.teal,
      Colors.purple,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lime,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Популярные товары (топ-${products.length})',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              final pct = maxQty > 0 ? (p.qty / maxQty) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        p.name.length > 18 ? '${p.name.substring(0, 18)}…' : p.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth * pct.clamp(0.0, 1.0);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: constraints.maxWidth,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.muted.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                width: w,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        p.qty == p.qty.roundToDouble()
                            ? p.qty.toInt().toString()
                            : p.qty.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(Map<DateTime, double> dataByDay) {
    final entries = dataByDay.entries.toList();
    if (entries.isEmpty) return const SizedBox();
    final total = entries.fold(0.0, (s, e) => s + e.value);
    final colors = [
      AppColors.primary,
      AppColors.accent,
      Colors.orange,
      Colors.teal,
      Colors.purple,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Доля выручки по дням (₸)',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: entries.asMap().entries.map((e) {
          final pct = total > 0 ? (e.value.value / total) : 0.0;
          return PieChartSectionData(
            value: e.value.value,
            title: '${(pct * 100).toStringAsFixed(0)}%',
            color: colors[e.key % colors.length],
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          );
        }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: entries.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value.key;
            final c = colors[i % colors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${d.day}.${d.month}',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
