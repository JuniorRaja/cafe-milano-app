import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app.dart';
import '../../../database/app_database.dart';
import '../../../providers/business_info_provider.dart';
import '../../../providers/database_provider.dart';

class BusinessInfoFormScreen extends ConsumerStatefulWidget {
  const BusinessInfoFormScreen({super.key});

  @override
  ConsumerState<BusinessInfoFormScreen> createState() =>
      _BusinessInfoFormScreenState();
}

class _BusinessInfoFormScreenState
    extends ConsumerState<BusinessInfoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Cafe Milano');
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _logoPath;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await ref.read(businessInfoProvider.future);
    if (info != null && mounted) {
      _nameCtrl.text = info.name;
      _phoneCtrl.text = info.phone ?? '';
      _addressCtrl.text = info.address ?? '';
      _logoPath = info.logoPath;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) setState(() => _logoPath = picked.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final companion = BusinessInfoCompanion(
      name: Value(_nameCtrl.text.trim()),
      phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
      address: Value(
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim()),
      logoPath: Value(_logoPath),
    );
    await ref.read(databaseProvider).businessInfoDao.upsertBusinessInfo(companion);
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Info',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Used on shared product catalogs',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
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
                          onTap: _pickLogo,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _logoPath != null
                                  ? Image.file(
                                      File(_logoPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Image.asset(kDefaultLogoAsset, fit: BoxFit.cover),
                                    )
                                  : Image.asset(kDefaultLogoAsset, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        if (_logoPath != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _logoPath = null),
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
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(_logoPath == null ? 'Upload Custom Logo' : 'Change Logo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business Name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: 'Contact number for quotations',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
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
