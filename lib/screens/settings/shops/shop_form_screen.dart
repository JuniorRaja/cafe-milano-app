import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';
import '../../../widgets/ui/ui.dart';

class ShopFormScreen extends ConsumerStatefulWidget {
  const ShopFormScreen({super.key, this.shopId});

  final int? shopId;

  @override
  ConsumerState<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends ConsumerState<ShopFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  DateTime? _openingBalanceAtDate;
  bool _openingBalanceLocked = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.shopId != null) {
      final shop = await ref
          .read(databaseProvider)
          .shopDao
          .getShop(widget.shopId!);
      if (shop != null && mounted) {
        _nameCtrl.text = shop.name;
        _areaCtrl.text = shop.area ?? '';
        _phoneCtrl.text = shop.phone ?? '';
        if (shop.openingBalance != null) {
          _openingBalanceCtrl.text = shop.openingBalance.toString();
        }
        _openingBalanceAtDate = shop.openingBalanceAt;
        _openingBalanceLocked = shop.openingBalance != null;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final openingBalanceText = _openingBalanceCtrl.text.trim();
    final companion = ShopsCompanion(
      id: widget.shopId != null ? Value(widget.shopId!) : const Value.absent(),
      name: Value(_nameCtrl.text.trim()),
      area: Value(_areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim()),
      phone: Value(
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      ),
      openingBalance: !_openingBalanceLocked && openingBalanceText.isNotEmpty
          ? Value(double.parse(openingBalanceText))
          : const Value.absent(),
      openingBalanceAt: !_openingBalanceLocked && openingBalanceText.isNotEmpty
          ? Value(_openingBalanceAtDate ?? DateTime.now())
          : const Value.absent(),
    );
    await ref.read(databaseProvider).shopDao.upsertShop(companion);
    if (mounted) context.pop();
  }

  Future<void> _pickOpeningBalanceAtDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingBalanceAtDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _openingBalanceAtDate = picked);
    }
  }

  Future<void> _delete() async {
    final isReferenced = await ref
        .read(databaseProvider)
        .shopDao
        .shopIsReferenced(widget.shopId!);
    if (!mounted) return;
    if (isReferenced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deactivate instead — this shop has existing orders, prices, or standing orders.',
          ),
        ),
      );
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete Shop',
      message: 'Delete this shop permanently?',
    );
    if (confirmed && mounted) {
      await ref.read(databaseProvider).shopDao.deleteShop(widget.shopId!);
      if (mounted) context.pop();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _phoneCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.shopId == null ? 'New Shop' : 'Edit Shop',
      caption: 'Fill in the shop details',
      background: AppColors.bg,
      actions: [
        if (widget.shopId != null)
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
                        AppField(
                          label: 'Shop name',
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
                          label: 'Area',
                          child: TextFormField(
                            controller: _areaCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Anna Nagar, Chennai',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Phone',
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppField(
                          label: 'Opening balance',
                          helper: _openingBalanceLocked
                              ? 'Set once — this is history.'
                              : null,
                          child: TextFormField(
                            controller: _openingBalanceCtrl,
                            enabled: !_openingBalanceLocked,
                            decoration: const InputDecoration(
                              hintText: 'Amount owed before using the ledger',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return double.tryParse(v.trim()) == null
                                  ? 'Enter a valid amount'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        AppButton.secondary(
                          label: _openingBalanceAtDate == null
                              ? 'As of date'
                              : 'As of '
                                    '${DateFormat('dd MMM yyyy').format(_openingBalanceAtDate!)}',
                          icon: Icons.calendar_today,
                          onPressed: _openingBalanceLocked
                              ? null
                              : _pickOpeningBalanceAtDate,
                        ),
                      ],
                    ),
                  ),
                  // Pinned, full width, dark brown. The Save button used to be
                  // the last row of the scroll, so on a form long enough to
                  // scroll you had to go looking for it.
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
