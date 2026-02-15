import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../state/cashier_state.dart';
import '../state/task_state.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.storage,
    required this.apiService,
    required this.child,
  });

  final Storage storage;
  final ApiService apiService;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TaskState _taskState;
  late final CashierState _cashierState;

  @override
  void initState() {
    super.initState();
    _taskState = TaskState(widget.apiService);
    _cashierState = CashierState();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return CashierStateScope(
      state: _cashierState,
      child: TaskStateScope(
      state: _taskState,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).viewPadding.top,
              bottom: MediaQuery.of(context).viewPadding.bottom,
              left: MediaQuery.of(context).viewPadding.left,
              right: MediaQuery.of(context).viewPadding.right,
            ),
            child: SafeArea(
              top: true,
              bottom: true,
              left: true,
              right: true,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Almaty-Foods\nАдмин',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _NavItem(
                          icon: PhosphorIconsRegular.chartLine,
                          label: 'Дашборд',
                          isSelected: location == '/dashboard',
                          onTap: () {
                            context.go('/dashboard');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.cashRegister,
                          label: 'Касса',
                          isSelected: location == '/cashier',
                          onTap: () {
                            context.go('/cashier');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.listBullets,
                          label: 'Категории',
                          isSelected: location == '/categories' ||
                              location.startsWith('/categories/'),
                          onTap: () {
                            context.go('/categories');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.package,
                          label: 'Товары',
                          isSelected: location == '/products' ||
                              location.startsWith('/products/'),
                          onTap: () {
                            context.go('/products');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.buildings,
                          label: 'Контрагенты',
                          isSelected: location == '/counterparties' ||
                              location.startsWith('/counterparties/'),
                          onTap: () {
                            context.go('/counterparties');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.package,
                          label: 'Сеты',
                          isSelected:
                              location == '/sets' || location.startsWith('/sets/'),
                          onTap: () {
                            context.go('/sets');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.money,
                          label: 'Продажи',
                          isSelected:
                              location == '/sales' || location.startsWith('/sales/'),
                          onTap: () {
                            context.go('/sales');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.creditCard,
                          label: 'Должники',
                          isSelected: location == '/debtors',
                          onTap: () {
                            context.go('/debtors');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.arrowDown,
                          label: 'Поступления',
                          isSelected: location == '/product-receipts' ||
                              location.startsWith('/product-receipts/'),
                          onTap: () {
                            context.go('/product-receipts');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.clipboardText,
                          label: 'Задачи',
                          isSelected: location == '/tasks',
                          onTap: () {
                            context.go('/tasks');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.identificationCard,
                          label: 'Реквизиты ИП',
                          isSelected: location == '/entrepreneur',
                          onTap: () {
                            context.go('/entrepreneur');
                            Navigator.of(context).pop();
                          },
                        ),
                        _NavItem(
                          icon: PhosphorIconsRegular.gear,
                          label: 'Настройки',
                          isSelected: location == '/settings',
                          onTap: () {
                            context.go('/settings');
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(PhosphorIconsRegular.signOut, size: 20),
                        label: const Text('Выйти'),
                        onPressed: () async {
                          await widget.apiService.logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: true,
          bottom: true,
          left: true,
          right: true,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.muted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.list),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? AppColors.primary : AppColors.muted,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.surface,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
}
