import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';
import '../theme/brand_config.dart';
import 'pdf_brand.dart';
import '../utils/money.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _shortDateFmt = DateFormat('dd MMM yy');

// Threaded rather than global: the statement is what a shop is handed, so
// the symbol and the digit grouping have to be the brand's, not a literal.
// The old version hardcoded '₹' with Western grouping and printed a shop's
// balance as 1,16,717.00 -> 116,717.00.

String _modeLabel(PaymentMode mode) => switch (mode) {
      PaymentMode.upi => 'UPI',
      PaymentMode.cash => 'Cash',
      PaymentMode.bank => 'Bank',
      PaymentMode.cheque => 'Cheque',
    };

/// One shop's account for one period: what they owed coming in, what moved,
/// and what they owe going out.
class StatementData {
  /// Balance carried into the period — every bill and payment before it, plus
  /// the shop's own opening balance.
  final double opening;
  final double billed;
  final double collected;
  final double closing;
  final List<LedgerEntry> rows;

  const StatementData({
    required this.opening,
    required this.billed,
    required this.collected,
    required this.closing,
    required this.rows,
  });
}

/// Splits a shop's full ledger into one period's statement.
///
/// Takes the whole history rather than a pre-filtered slice on purpose: the
/// opening balance of a mid-period statement is the running balance of the
/// last entry *before* the period, which a filtered list cannot tell you.
/// Because this reads the same [LedgerEntry] list the ledger screen renders
/// and reuses [ledgerEntryInRange] for the period test, the statement and the
/// screen cannot disagree about the same period.
///
/// [entries] must be the chronological, unfiltered result of
/// `watchShopLedger(shopId)`, and [shopOpeningBalance] the shop's own opening
/// balance — the answer when the period starts before any entry at all.
StatementData buildStatementData({
  required List<LedgerEntry> entries,
  required DateTime from,
  required DateTime to,
  required double shopOpeningBalance,
}) {
  var opening = shopOpeningBalance;
  final rows = <LedgerEntry>[];
  var billed = 0.0;
  var collected = 0.0;

  for (final entry in entries) {
    if (!ledgerEntryInRange(entry, null, to)) break; // chronological, so done
    if (!ledgerEntryInRange(entry, from, null)) {
      // Before the period: history, but its running balance is exactly what
      // the shop owed at that moment, so the last one *is* the opening balance.
      opening = entry.runningBalance;
      continue;
    }
    rows.add(entry);
    if (entry.type == LedgerType.bill) {
      billed += entry.amount;
    } else {
      collected += entry.amount;
    }
  }

  return StatementData(
    opening: opening,
    billed: billed,
    collected: collected,
    closing: opening + billed - collected,
    rows: rows,
  );
}

String _description(LedgerEntry entry) {
  if (entry.type == LedgerType.bill) return 'Bill';
  final note = entry.note?.trim();
  final base = 'Payment · ${_modeLabel(entry.paymentMode!)}';
  return (note == null || note.isEmpty) ? base : '$base — $note';
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

pw.Widget _cell(String text,
    {bool bold = false, PdfColor? color, bool right = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}

pw.Widget _statementHeader(
  Shop shop,
  BusinessInfoData? business,
  DateTime from,
  DateTime to,
) {
  final area = shop.area?.trim();
  final address = business?.address?.trim();
  final phone = business?.phone?.trim();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  shop.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: kPdfBrown,
                  ),
                ),
                if (area != null && area.isNotEmpty)
                  pw.Text(
                    area,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                business?.name ?? BrandConfig.milano.appName,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              if (address != null && address.isNotEmpty)
                pw.Text(
                  address,
                  textAlign: pw.TextAlign.right,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              if (phone != null && phone.isNotEmpty)
                pw.Text(
                  'Ph $phone',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(height: 3, color: kPdfGold),
      pw.SizedBox(height: 6),
      pw.Text(
        'Statement · ${_dateFmt.format(from)} – ${_dateFmt.format(to)}',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: kPdfBrown,
        ),
      ),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _entriesTable(BrandConfig brand, StatementData data) {
  final header = pw.TableRow(
    // repeat: the header re-draws at the top of every page the table spills
    // onto, so page 3 of a long statement still reads on its own.
    repeat: true,
    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
    children: [
      _cell('Date', bold: true),
      _cell('Description', bold: true),
      _cell('Dr', bold: true, right: true),
      _cell('Cr', bold: true, right: true),
      _cell('Balance', bold: true, right: true),
    ],
  );

  final openingRow = pw.TableRow(
    children: [
      _cell(''),
      _cell('Opening balance', bold: true),
      _cell(''),
      _cell(''),
      _cell(brand.moneyDecimal(data.opening), bold: true, right: true),
    ],
  );

  final rows = data.rows.map((entry) {
    final isBill = entry.type == LedgerType.bill;
    return pw.TableRow(
      children: [
        _cell(_shortDateFmt.format(entry.date)),
        _cell(_description(entry)),
        _cell(isBill ? brand.moneyDecimal(entry.amount) : '', right: true),
        _cell(isBill ? '' : brand.moneyDecimal(entry.amount), right: true),
        _cell(brand.moneyDecimal(entry.runningBalance), right: true),
      ],
    );
  });

  return pw.Table(
    border: pw.TableBorder.symmetric(
      inside: const pw.BorderSide(width: 0.5, color: PdfColors.grey300),
    ),
    columnWidths: const {
      0: pw.FixedColumnWidth(58),
      1: pw.FlexColumnWidth(),
      2: pw.FixedColumnWidth(72),
      3: pw.FixedColumnWidth(72),
      4: pw.FixedColumnWidth(80),
    },
    children: [header, openingRow, ...rows],
  );
}

pw.Widget _summaryBlock(BrandConfig brand, StatementData data) {
  pw.Widget line(String label, String value, {bool emphasis = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: emphasis ? 12 : 10,
              fontWeight: emphasis ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: emphasis ? kPdfBrown : PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: emphasis ? 12 : 10,
              fontWeight: pw.FontWeight.bold,
              color: emphasis ? kPdfBrown : PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14),
    child: pw.Row(
      children: [
        pw.Spacer(),
        pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              line('Opening balance', brand.moneyDecimal(data.opening)),
              line('Total Billed', brand.moneyDecimal(data.billed)),
              line('Total Collected', brand.moneyDecimal(data.collected)),
              pw.Divider(thickness: 0.5, color: kPdfGold),
              line('Closing balance', brand.moneyDecimal(data.closing), emphasis: true),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<Uint8List> buildStatementPdf({
  required BrandConfig brand,
  required Shop shop,
  required BusinessInfoData? business,
  required StatementData data,
  required DateTime from,
  required DateTime to,
}) async {
  final doc = pw.Document(theme: await loadPdfTheme());

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
        buildBackground: pdfWhiteBackground,
      ),
      footer: (context) => pdfPageFooter(context, business),
      build: (context) => [
        _statementHeader(shop, business, from, to),
        _entriesTable(brand, data),
        if (data.rows.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'No bills or payments in this period.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        _summaryBlock(brand, data),
      ],
    ),
  );

  return doc.save();
}

/// Builds the statement for [from]–[to] and hands it to the share sheet.
Future<void> shareLedgerStatement({
  required BrandConfig brand,
  required Shop shop,
  required BusinessInfoData? business,
  required List<LedgerEntry> entries,
  required DateTime from,
  required DateTime to,
}) async {
  final data = buildStatementData(
    entries: entries,
    from: from,
    to: to,
    shopOpeningBalance: shop.openingBalance ?? 0.0,
  );
  final bytes = await buildStatementPdf(
    brand: brand,
    shop: shop,
    business: business,
    data: data,
    from: from,
    to: to,
  );
  final slug = shop.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'statement-$slug-${DateFormat('yyyyMMdd').format(from)}.pdf',
  );
}
