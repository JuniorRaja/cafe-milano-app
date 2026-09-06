import 'dart:async';
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
import '../../../widgets/ui/ui.dart';

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
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.productId != null) {
      final product = await ref
          .read(databaseProvider)
          .productDao
          .getProduct(widget.productId!);
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
      id: widget.productId != null
          ? Value(widget.productId!)
          : const Value.absent(),
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
    final isReferenced = await ref
        .read(databaseProvider)
        .productDao
        .productIsReferenced(widget.productId!);
    if (!mounted) return;
    if (isReferenced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deactivate instead — this product has existing order lines, prices, or standing orders.',
          ),
        ),
      );
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete Product',
      message: 'Delete this product permanently?',
    );
    if (confirmed && mounted) {
      await ref
          .read(databaseProvider)
          .productDao
          .deleteProduct(widget.productId!);
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
    // Not `maybeWhen(orElse: [])`. An empty list because the query *failed*
    // is a dropdown with nothing in it and no explanation — the field just
    // looks broken. `_selectedCategoryId` is local state and survives either
    // way, so nothing is lost; the failure is said out loud instead.
    final catsAsync = ref.watch(allCategoriesProvider);
    final catsFailed = catsAsync.hasError;
    final allCats = catsAsync.valueOrNull ?? const <Category>[];
    final activeCats = allCats.where((c) => c.isActive).toList();
    // Ensure selected (possibly inactive) category is always in items to avoid dropdown assertion
    final selectedIsActive =
        _selectedCategoryId == null ||
        activeCats.any((c) => c.id == _selectedCategoryId);
    final inactiveCatForValue = selectedIsActive
        ? null
        : allCats.where((c) => c.id == _selectedCategoryId).firstOrNull;

    return AppScaffold(
      title: widget.productId == null ? 'New Product' : 'Edit Product',
      caption: 'Fill in the product details',
      background: AppColors.bg,
      actions: [
        if (widget.productId != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: AppColors.negative,
            onPressed: _saving ? null : _delete,
          ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4,
                        0,
                        AppSpace.s4,
                        AppSpace.s4,
                      ),
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
                                    color: AppColors.surfaceMuted,
                                    borderRadius: AppRadius.rS,
                                  ),
                                  child: _photoPath != null
                                      ? ClipRRect(
                                          borderRadius: AppRadius.rS,
                                          child: Image.file(
                                            File(_photoPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 40,
                                        ),
                                ),
                              ),
                              if (_photoPath != null)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _photoPath = null),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
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
                            label: Text(
                              _photoPath == null ? 'Add Photo' : 'Change Photo',
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Product name',
                          isRequired: true,
                          child: TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Price',
                          child: TextFormField(
                            controller: _priceCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Default price (optional)',
                              prefixText: '₹ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
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
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Unit',
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedUnit,
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
                        ),
                        if (_selectedUnit == _kOtherUnit) ...[
                          const SizedBox(height: AppSpace.s4),
                          AppField(
                            label: 'Custom unit',
                            isRequired: true,
                            child: TextFormField(
                              controller: _unitCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. tray, sack',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter a unit'
                                  : null,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Category',
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCategoryId,
                            decoration: InputDecoration(
                              errorText: catsFailed
                                  ? 'Categories could not be loaded. This product '
                                        'keeps the category it already has.'
                                  : null,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Uncategorised'),
                              ),
                              for (final cat in activeCats)
                                DropdownMenuItem<int?>(
                                  value: cat.id,
                                  child: Text(
                                    '${emojiFor(cat.name)} ${cat.name}',
                                  ),
                                ),
                              if (inactiveCatForValue != null)
                                DropdownMenuItem<int?>(
                                  value: inactiveCatForValue.id,
                                  child: Text(
                                    '${emojiFor(inactiveCatForValue.name)} ${inactiveCatForValue.name} (inactive)',
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedCategoryId = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pinned, full width, dark brown — it was the last row of
                  // the scroll, so on a form long enough to scroll you had to
                  // go looking for it.
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: AppButton(
                        label: 'Save',
                        expand: true,
                        busy: _saving,
                        onPressed: _save,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
