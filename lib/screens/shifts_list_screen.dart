import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import '../widgets/z_report_dialog.dart';

class ShiftsListScreen extends StatefulWidget {
  const ShiftsListScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<ShiftsListScreen> createState() => _ShiftsListScreenState();
}

class _ShiftsListScreenState extends State<ShiftsListScreen> {
  List<Shift> _shifts = [];
  bool _isLoading = true;
  String? _error;

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
      final list = await widget.apiService.getShifts();
      if (!mounted) return;
      final sorted = List<Shift>.from(list)..sort((a, b) => b.id.compareTo(a.id));
      setState(() {
        _shifts = sorted;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить смены';
        _isLoading = false;
      });
    }
  }

  String _formatShiftTitle(Shift s) {
    final opened =
        '${s.openedAt.day.toString().padLeft(2, '0')}.${s.openedAt.month.toString().padLeft(2, '0')}.${s.openedAt.year} '
        '${s.openedAt.hour.toString().padLeft(2, '0')}:${s.openedAt.minute.toString().padLeft(2, '0')}';
    if (s.closedAt != null) {
      final closed =
          '${s.closedAt!.hour.toString().padLeft(2, '0')}:${s.closedAt!.minute.toString().padLeft(2, '0')}';
      return '$opened – $closed';
    }
    return '$opened (открыта)';
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
              bottom: BorderSide(color: AppColors.muted.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Продажи',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/sales/search'),
                icon: const Icon(Icons.search, size: 20),
                label: const Text('Поиск продажи'),
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
                          Icon(Icons.error_outline,
                              size: 48, color: AppColors.danger),
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
                  : _shifts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.schedule,
                                  size: 64, color: AppColors.muted),
                              const SizedBox(height: 16),
                              Text(
                                'Нет смен',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _shifts.length,
                            itemBuilder: (context, index) {
                              final shift = _shifts[index];
                              final zReport = shift.webkassaZReport;
                              final showZ = !shift.isOpen &&
                                  ZReportDialog.hasViewableData(zReport);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () => context.push(
                                    '/sales/shift/${shift.id}',
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              AppColors.primaryLight,
                                          child: Icon(
                                            shift.isOpen
                                                ? Icons.play_circle_filled
                                                : Icons.stop_circle,
                                            color: shift.isOpen
                                                ? AppColors.accent
                                                : AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatShiftTitle(shift),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                shift.isOpen
                                                    ? 'Открыта'
                                                    : shift.hasZReport
                                                        ? 'Закрыта · Z-отчёт'
                                                        : 'Закрыта',
                                                style: TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (showZ)
                                          IconButton(
                                            tooltip: 'Z-отчёт WebKassa',
                                            icon: const Icon(
                                              Icons.summarize_outlined,
                                            ),
                                            onPressed: () {
                                              ZReportDialog.show(
                                                context,
                                                zReport: zReport!,
                                                zReportAt:
                                                    shift.webkassaZReportAt,
                                              );
                                            },
                                          ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppColors.muted,
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
