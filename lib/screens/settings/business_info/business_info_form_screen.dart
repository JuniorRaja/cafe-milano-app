import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/ui/ui.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/brand_config.dart';
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
  final _nameCtrl = TextEditingController(text: BrandConfig.milano.appName);
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _logoPath;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      phone: Value(
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      ),
      address: Value(
        _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      ),
      logoPath: Value(_logoPath),
    );
    await ref
        .read(databaseProvider)
        .businessInfoDao
        .upsertBusinessInfo(companion);
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
    return AppScaffold(
      title: 'Business Info',
      caption: 'Used on shared product catalogs',
      background: AppColors.bg,
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
                                onTap: _pickLogo,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: AppRadius.rS,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: AppRadius.rS,
                                    child: _logoPath != null
                                        ? Image.file(
                                            File(_logoPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                Image.asset(
                                                  BrandConfig.milano.logoAsset,
                                                  fit: BoxFit.cover,
                                                ),
                                          )
                                        : Image.asset(
                                            BrandConfig.milano.logoAsset,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),
                              if (_logoPath != null)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _logoPath = null),
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
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _logoPath == null
                                  ? 'Upload Custom Logo'
                                  : 'Change Logo',
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Business name',
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
                          label: 'Phone',
                          child: TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Contact number for quotations',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Address',
                          child: TextFormField(
                            controller: _addressCtrl,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
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
