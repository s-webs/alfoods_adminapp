import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/user.dart' as app_user;
import '../services/api_service.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({
    super.key,
    required this.apiService,
    this.userId,
    this.mode = UserFormMode.create,
  });

  final ApiService apiService;
  final int? userId;
  final UserFormMode mode;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

enum UserFormMode { create, edit }

final List<MapEntry<String, String>> _roleOptions = [
  MapEntry('admin', 'Administrator'),
  MapEntry('manager', 'Manager'),
  MapEntry('cashier', 'Cashier'),
  MapEntry('viewer', 'Viewer'),
  MapEntry('shopper', 'Покупатель'),
  MapEntry('wholesale', 'Оптовик'),
];

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _personalDiscountController = TextEditingController();

  app_user.User? _user;
  String _selectedRole = 'viewer';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.mode == UserFormMode.edit && widget.userId != null) {
      _load();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _personalDiscountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await widget.apiService.getUser(widget.userId!);
      if (!mounted) return;
      setState(() {
        _user = user;
        _nameController.text = user.name;
        _emailController.text = user.email;
        _selectedRole = user.role;
        _personalDiscountController.text = user.personalDiscountPercent != null
            ? user.personalDiscountPercent!.toString()
            : '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить пользователя';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) return;

    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;
    if (widget.mode == UserFormMode.create) {
      if (password.length < 8) return;
      if (password != passwordConfirmation) return;
    } else {
      if (password.isNotEmpty && (password.length < 8 || password != passwordConfirmation)) return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        'role': _selectedRole,
        'personal_discount_percent': _personalDiscountController.text.trim().isEmpty
            ? null
            : double.tryParse(_personalDiscountController.text.trim().replaceAll(',', '.')),
      };
      if (widget.mode == UserFormMode.create) {
        data['password'] = password;
        data['password_confirmation'] = passwordConfirmation;
        await widget.apiService.createUser(data);
      } else {
        if (password.isNotEmpty) {
          data['password'] = password;
          data['password_confirmation'] = passwordConfirmation;
        }
        await widget.apiService.updateUser(widget.userId!, data);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().contains('422')
            ? 'Ошибка валидации. Проверьте поля.'
            : 'Не удалось сохранить';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _user == null && widget.mode == UserFormMode.edit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Пользователь')),
        body: Center(
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
          widget.mode == UserFormMode.edit ? 'Редактирование' : 'Новый пользователь',
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
                      Icon(
                        PhosphorIconsRegular.warningCircle,
                        color: AppColors.danger,
                      ),
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
                  labelText: 'Имя *',
                  hintText: 'Введите имя',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'email@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                  if (!v.contains('@') || !v.contains('.')) return 'Некорректный email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.mode == UserFormMode.create
                      ? 'Пароль *'
                      : 'Новый пароль (оставьте пустым, чтобы не менять)',
                  hintText: widget.mode == UserFormMode.create
                      ? 'Минимум 8 символов'
                      : 'Минимум 8 символов',
                ),
                validator: (v) {
                  if (widget.mode == UserFormMode.create) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < 8) return 'Минимум 8 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordConfirmationController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Подтверждение пароля',
                  hintText: 'Повторите пароль',
                ),
                validator: (v) {
                  if (widget.mode == UserFormMode.create) {
                    if (v == null || v.isEmpty) return 'Подтвердите пароль';
                    if (v != _passwordController.text) return 'Пароли не совпадают';
                  } else if (_passwordController.text.isNotEmpty) {
                    if (v != _passwordController.text) return 'Пароли не совпадают';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Роль *',
                ),
                items: _roleOptions
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _personalDiscountController,
                decoration: const InputDecoration(
                  labelText: 'Персональная скидка (%)',
                  hintText: '0–100, необязательно',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (n == null || n < 0 || n > 100) {
                    return 'Введите число от 0 до 100';
                  }
                  return null;
                },
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
            ],
          ),
        ),
      ),
    );
  }
}
