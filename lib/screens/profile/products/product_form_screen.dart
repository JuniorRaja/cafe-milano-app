import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../database/app_database.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../services/category_emoji.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

const _kUnitOptions = [
  'pc',
  'kg',
  'g',
  'dozen',
  'box',
  'packet',
  'litre',
  'ml',
];
const _kOtherUnit = 'Other';

String _formatPrice(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _selectedUnit;
  String? _photoPath;
  int? _selectedCategoryId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.productId != null) {
      final product =
          await ref.read(databaseProvider).productDao.getProduct(widget.productId!);
      if (product != null && mounted) {
        _nameCtrl.text = product.name;
        _photoPath = product.photoPath;
        _selectedCategoryId = product.categoryId;
        if (product.price != null) {
          _priceCtrl.text = _formatPrice(product.price!);
        }
        final unit = product.unit;
        if (unit != null && unit.isNotEmpty) {
          if (_kUnitOptions.contains(unit)) {
            _selectedUnit = unit;
          } else {
            _selectedUnit = _kOtherUnit;
            _unitCtrl.text = unit;
          }
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) setState(() => _photoPath = picked.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final unit = _selectedUnit == _kOtherUnit
        ? _unitCtrl.text.trim()
        : _selectedUnit;
    final priceText = _priceCtrl.text.trim();
    final companion = ProductsCompanion(
      id: widget.productId != null ? Value(widget.productId!) : const Value.absent(),
      name: Value(_nameCtrl.text.trim()),
      unit: Value(unit == null || unit.isEmpty ? null : unit),
      photoPath: Value(_photoPath),
      price: Value(priceText.isEmpty ? null : double.parse(priceText)),
      categoryId: Value(_selectedCategoryId),
    );
    await ref.read(databaseProvider).productDao.upsertProduct(companion);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final hasLines = await ref
        .read(databaseProvider)
        .productDao
        .productHasOrderLines(widget.productId!);
    if (!mounted) return;
    if (hasLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deactivate instead — this product has existing order lines.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Delete this product permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(databaseProvider).productDao.deleteProduct(widget.productId!);
      if (mounted) context.pop();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCats = ref.watch(allCategoriesProvider).maybeWhen(
          data: (c) => c,
          orElse: () => <Category>[],
        );
    final activeCats = allCats.where((c) => c.isActive).toList();
    // Ensure selected (possibly inactive) category is always in items to avoid dropdown assertion
    final selectedIsActive =
        _selectedCategoryId == null || activeCats.any((c) => c.id == _selectedCategoryId);
    final inactiveCatForValue = selectedIsActive
        ? null
        : allCats.where((c) => c.id == _selectedCategoryId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productId == null ? 'New Product' : 'Edit Product',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Fill in the product details',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (widget.productId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _photoPath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_photoPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.broken_image, size: 40),
                                    ),
                                  )
                                : const Icon(Icons.add_a_photo_outlined, size: 40),
                          ),
                        ),
                        if (_photoPath != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _photoPath = null),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(_photoPath == null ? 'Add Photo' : 'Change Photo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'Default price (optional)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final u in _kUnitOptions)
                        DropdownMenuItem(value: u, child: Text(u)),
                      const DropdownMenuItem(
                        value: _kOtherUnit,
                        child: Text(_kOtherUnit),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedUnit = v),
                  ),
                  if (_selectedUnit == _kOtherUnit) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom Unit',
                        hintText: 'e.g. tray, sack',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a unit'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Uncategorised')),
                      for (final cat in activeCats)
                        DropdownMenuItem<int?>(
                          value: cat.id,
                          child: Text('${emojiFor(cat.name)} ${cat.name}'),
                        ),
                      if (inactiveCatForValue != null)
                        DropdownMenuItem<int?>(
                          value: inactiveCatForValue.id,
                          child: Text(
                              '${emojiFor(inactiveCatForValue.name)} ${inactiveCatForValue.name} (inactive)'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
