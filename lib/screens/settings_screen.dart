import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../utils/toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.storage,
    required this.apiService,
  });

  final Storage storage;
  final ApiService apiService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  late TextEditingController _urlController;
  late TextEditingController _nameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingUrl = false;
  bool _isSavingName = false;
  bool _isSavingPassword = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.storage.baseUrl ?? '');
    final user = widget.storage.user;
    _nameController = TextEditingController(
      text: user != null ? (user['name'] as String? ?? '') : '',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    if (!_urlKey.currentState!.validate()) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showToast(context, 'Введите URL');
      return;
    }
    setState(() => _isSavingUrl = true);
    try {
      final normalized = url.endsWith('/') ? url : '$url/';
      await widget.storage.setBaseUrl(normalized);
      widget.apiService.reconfigureClient();
      if (mounted) showToast(context, 'URL сохранён');
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSavingUrl = false);
    }
  }

  Future<void> _saveName() async {
    if (!_nameKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Введите имя');
      return;
    }
    setState(() => _isSavingName = true);
    try {
      await widget.apiService.updateProfile(name: name);
      if (mounted) showToast(context, 'Имя сохранено');
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    final current = _currentPasswordController.text;
    final newPwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (current.isEmpty || newPwd.isEmpty) {
      showToast(context, 'Заполните текущий и новый пароль');
      return;
    }
    if (newPwd != confirm) {
      showToast(context, 'Новый пароль и подтверждение не совпадают');
      return;
    }
    if (newPwd.length < 8) {
      showToast(context, 'Пароль не менее 8 символов');
      return;
    }
    setState(() => _isSavingPassword = true);
    try {
      await widget.apiService.updatePassword(
        currentPassword: current,
        newPassword: newPwd,
      );
      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        showToast(context, 'Пароль изменён');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('404') || e.toString().contains('422')
            ? 'Сервер не поддерживает смену пароля или неверный текущий пароль'
            : 'Ошибка: $e';
        showToast(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'URL API',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Form(
            key: _urlKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://example.com',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите URL';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSavingUrl ? null : _saveUrl,
                  child: _isSavingUrl
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Имя',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Form(
            key: _nameKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Ваше имя',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите имя';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSavingName ? null : _saveName,
                  child: _isSavingName
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Смена пароля',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Form(
            key: _passwordKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Текущий пароль',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите текущий пароль';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите новый пароль';
                    if (v.length < 8) return 'Не менее 8 символов';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Подтверждение пароля',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v != _newPasswordController.text) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSavingPassword ? null : _savePassword,
                  icon: _isSavingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(PhosphorIconsRegular.lock, size: 20),
                  label: Text(_isSavingPassword ? 'Сохранение…' : 'Изменить пароль'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
