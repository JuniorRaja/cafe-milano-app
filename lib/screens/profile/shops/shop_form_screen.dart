import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';

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
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.shopId != null) {
      final shop = await ref.read(databaseProvider).shopDao.getShop(widget.shopId!);
      if (shop != null && mounted) {
        _nameCtrl.text = shop.name;
        _areaCtrl.text = shop.area ?? '';
        _phoneCtrl.text = shop.phone ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final companion = ShopsCompanion(
      id: widget.shopId != null ? Value(widget.shopId!) : const Value.absent(),
      name: Value(_nameCtrl.text.trim()),
      area: Value(_areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim()),
      phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
    );
    await ref.read(databaseProvider).shopDao.upsertShop(companion);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final hasOrders =
        await ref.read(databaseProvider).shopDao.shopHasOrders(widget.shopId!);
    if (!mounted) return;
    if (hasOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deactivate instead — this shop has existing orders.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shop'),
        content: const Text('Delete this shop permanently?'),
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
      await ref.read(databaseProvider).shopDao.deleteShop(widget.shopId!);
      if (mounted) context.pop();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _phoneCtrl.dispose();
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
