import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/slugify.dart';

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({
    super.key,
    required this.apiService,
    this.categoryId,
    this.mode = CategoryFormMode.create,
  });

  final ApiService apiService;
  final int? categoryId;
  final CategoryFormMode mode;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

enum CategoryFormMode { create, edit }

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();

  Category? _category;
  Color? _colorFrom;
  Color? _colorTo;
  String? _image;
  bool _isUploadingImage = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.mode == CategoryFormMode.edit && widget.categoryId != null) {
      _load();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  static Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v != null ? Color(0xFF000000 | v) : null;
  }

  static String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getCategories();
      final cat = list.where((c) => c.id == widget.categoryId).firstOrNull;
      if (!mounted) return;
      if (cat != null) {
        setState(() {
          _category = cat;
          _nameController.text = cat.name;
          _slugController.text = cat.slug;
          _image = cat.image;
          _colorFrom = _hexToColor(cat.colorFrom);
          _colorTo = _hexToColor(cat.colorTo);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Категория не найдена';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить категорию';
        _isLoading = false;
      });
    }
  }

  void _onNameChanged(String value) {
    if (widget.mode == CategoryFormMode.create &&
        _slugController.text.isEmpty) {
      _slugController.text = slugify(value);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim();
    if (name.isEmpty || slug.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': name,
        'slug': slug,
        'sort_order': _category?.sortOrder ?? 0,
        'parent_id': _category?.parentId,
        'is_active': _category?.isActive ?? true,
      };
      if (_image != null && _image!.isNotEmpty) data['image'] = _image;
      if (_colorFrom != null) data['color_from'] = _colorToHex(_colorFrom!);
      if (_colorTo != null) data['color_to'] = _colorToHex(_colorTo!);
      if (widget.mode == CategoryFormMode.edit && widget.categoryId != null) {
        await widget.apiService.updateCategory(widget.categoryId!, data);
      } else {
        await widget.apiService.createCategory(data);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().contains('422')
            ? 'Ошибка валидации (проверьте slug)'
            : 'Не удалось сохранить';
      });
    }
  }

  Future<void> _delete() async {
    if (widget.categoryId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория «${_category?.name ?? ''}» будет удалена безвозвратно.',
        ),
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
      await widget.apiService.deleteCategory(widget.categoryId!);
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

  Future<void> _pickAndUploadImage({bool useCamera = false}) async {
    String? path;
    String? filename;
    if (useCamera) {
      final x = await ImagePicker().pickImage(source: ImageSource.camera);
      if (x == null || !mounted) return;
      path = x.path;
      filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty || !mounted) return;
      final f = result.files.first;
      path = f.path;
      filename = f.name;
    }
    if (path == null || path.isEmpty) return;
    setState(() => _isUploadingImage = true);
    try {
      final p = await widget.apiService.uploadCategoryImage(path, filename: filename);
      if (!mounted) return;
      setState(() => _image = p);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Категория')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _category == null && widget.mode == CategoryFormMode.edit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Категория')),
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
          widget.mode == CategoryFormMode.edit ? 'Редактирование' : 'Новая категория',
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
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                onChanged: _onNameChanged,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  hintText: 'category-slug',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 16),
              const Text('Картинка', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_image != null && _image!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _image!.startsWith('http') ? _image! : widget.apiService.fileUrl(_image!),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: AppColors.muted),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (!_isUploadingImage) ...[
                    OutlinedButton.icon(
                      onPressed: () => _pickAndUploadImage(useCamera: false),
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: Text(_image != null && _image!.isNotEmpty ? 'Заменить' : 'Выбрать'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickAndUploadImage(useCamera: true),
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Камера'),
                    ),
                  ]
                  else
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  if (_image != null && _image!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _image = null),
                      icon: const Icon(Icons.clear, color: AppColors.danger),
                      tooltip: 'Удалить картинку',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const Text('Цвет от', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  Color pickerColor = _colorFrom ?? Colors.green;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx2, setDialogState) => AlertDialog(
                        title: const Text('Цвет от'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: pickerColor,
                            onColorChanged: (c) {
                              pickerColor = c;
                              setDialogState(() {});
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (ok == true && mounted) setState(() => _colorFrom = pickerColor);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _colorFrom ?? Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.muted),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _colorFrom != null ? _colorToHex(_colorFrom!) : 'Нажмите для выбора',
                    style: TextStyle(
                      color: _colorFrom != null && _colorFrom!.computeLuminance() < 0.5
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Цвет до', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  Color pickerColor = _colorTo ?? Colors.green.shade700;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx2, setDialogState) => AlertDialog(
                        title: const Text('Цвет до'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: pickerColor,
                            onColorChanged: (c) {
                              pickerColor = c;
                              setDialogState(() {});
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (ok == true && mounted) setState(() => _colorTo = pickerColor);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _colorTo ?? Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.muted),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _colorTo != null ? _colorToHex(_colorTo!) : 'Нажмите для выбора',
                    style: TextStyle(
                      color: _colorTo != null && _colorTo!.computeLuminance() < 0.5
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              if (_colorFrom != null || _colorTo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _colorFrom = null;
                      _colorTo = null;
                    }),
                    child: const Text('Очистить цвета'),
                  ),
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
              if (widget.mode == CategoryFormMode.edit) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _delete();
                        },
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
