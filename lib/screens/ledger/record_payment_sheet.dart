import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/ledger_provider.dart';

/// A specific bill this payment is being recorded *for*, rather than "oldest
/// first". Set by Mark-as-Paid on the billing screen, where the shop has paid
/// a named bill on the day it was delivered.
typedef PinnedBill = ({int orderId, DateTime date, double amountDue});

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.shopId, this.pinned});

  final int shopId;

  /// Null for an ordinary payment, which allocates FIFO as before.
  final PinnedBill? pinned;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  PaymentMode _mode = PaymentMode.cash;
  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pinned = widget.pinned;
    if (pinned != null) {
      _amountCtrl.text = pinned.amountDue.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _paidAt = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.parse(_amountCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    await ref.read(databaseProvider).ledgerDao.recordPayment(
          shopId: widget.shopId,
          amount: amount,
          paidAt: _paidAt,
          mode: _mode,
          note: note.isEmpty ? null : note,
          priorityOrderId: widget.pinned?.orderId,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.pinned;
    final outstanding =
        ref.watch(shopStatsProvider(widget.shopId)).value?.outstanding;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record Payment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (pinned != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Text(
                  'Settling the ${DateFormat('dd MMM yyyy').format(pinned.date)} bill '
                  '· ₹${pinned.amountDue.toStringAsFixed(2)} due',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
            if (pinned == null && outstanding != null && outstanding > 0.005) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Outstanding ₹${outstanding.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(
                      () => _amountCtrl.text = outstanding.toStringAsFixed(2),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Settle full', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Mode', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 8),
            SegmentedButton<PaymentMode>(
              segments: const [
                ButtonSegment(value: PaymentMode.cash, label: Text('Cash')),
                ButtonSegment(value: PaymentMode.upi, label: Text('UPI')),
                ButtonSegment(value: PaymentMode.bank, label: Text('Bank')),
                ButtonSegment(value: PaymentMode.cheque, label: Text('Cheque')),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) => setState(() => _mode = selected.first),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('dd MMM yyyy').format(_paidAt)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            // TODO(doc 06): manual allocation panel goes here
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
            ),
          ],
        ),
      ),
    );
  }
}
