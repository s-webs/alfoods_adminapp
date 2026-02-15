import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/storage.dart';
import '../core/theme.dart';
import '../utils/toast.dart';

/// Экран реквизитов ИП для автозаполнения накладных.
class EntrepreneurDetailsScreen extends StatefulWidget {
  const EntrepreneurDetailsScreen({
    super.key,
    required this.storage,
  });

  final Storage storage;

  @override
  State<EntrepreneurDetailsScreen> createState() =>
      _EntrepreneurDetailsScreenState();
}

class _EntrepreneurDetailsScreenState extends State<EntrepreneurDetailsScreen> {
  final _nameController = TextEditingController();
  final _binController = TextEditingController();
  final _managerController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.storage.entrepreneurName ?? '';
    _binController.text = widget.storage.entrepreneurBin ?? '';
    _managerController.text = widget.storage.entrepreneurManager ?? '';
    _addressController.text = widget.storage.entrepreneurAddress ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _binController.dispose();
    _managerController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.storage.setEntrepreneurName(
        _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );
      await widget.storage.setEntrepreneurBin(
        _binController.text.trim().isEmpty
            ? null
            : _binController.text.trim(),
      );
      await widget.storage.setEntrepreneurManager(
        _managerController.text.trim().isEmpty
            ? null
            : _managerController.text.trim(),
      );
      await widget.storage.setEntrepreneurAddress(
        _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      if (mounted) showToast(context, 'Реквизиты сохранены');
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Реквизиты ИП'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.go('/categories'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Данные для автозаполнения накладных (форма 3-2). Заполните и сохраните — они подставятся в диалог накладной на экране продажи.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название ИП',
              hintText: 'Индивидуальный предприниматель «Название»',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _binController,
            decoration: const InputDecoration(
              labelText: 'БИН',
              hintText: '12 цифр',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 12,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerController,
            decoration: const InputDecoration(
              labelText: 'Руководитель',
              hintText: 'Ф.И.О. руководителя',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Адрес',
              hintText: 'Юридический адрес или адрес деятельности',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.floppyDisk, size: 20),
            label: Text(_isSaving ? 'Сохранение…' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}
