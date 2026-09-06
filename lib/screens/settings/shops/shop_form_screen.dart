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
      final shop = await ref.read(databaseProvider).shopDao.getShop(widget.shopId!);
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
      phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
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
    final isReferenced =
        await ref.read(databaseProvider).shopDao.shopIsReferenced(widget.shopId!);
    if (!mounted) return;
    if (isReferenced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Deactivate instead — this shop has existing orders, prices, or standing orders.'),
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.shopId == null ? 'New Shop' : 'Edit Shop',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Fill in the shop details',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (widget.shopId != null)
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
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop Name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _areaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Area',
                      hintText: 'e.g. Anna Nagar, Chennai',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _openingBalanceCtrl,
                    enabled: !_openingBalanceLocked,
                    decoration: InputDecoration(
                      labelText: 'Opening Balance',
                      hintText: 'Amount owed before using the ledger',
                      helperText: _openingBalanceLocked
                          ? 'Set once — this is history.'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return double.tryParse(v.trim()) == null
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openingBalanceLocked ? null : _pickOpeningBalanceAtDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _openingBalanceAtDate == null
                          ? 'As of Date'
                          : 'As of ${DateFormat('dd MMM yyyy').format(_openingBalanceAtDate!)}',
                    ),
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
