import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/app_database.dart';
import '../theme/brand_config.dart';

// Everything that makes a generated PDF look like this business rather than a
// default pdf-package document, in one place so the catalogue and the shop
// statement cannot drift into two visual languages.

// Brand colours as PDF equivalents of kBrandGold / kBrandBrown from app.dart
const kPdfGold  = PdfColor(1.0, 192 / 255, 0.0);         // 0xFFFFC000
const kPdfBrown = PdfColor(74 / 255, 44 / 255, 42 / 255); // 0xFF4A2C2A

Future<pw.ThemeData> loadPdfTheme() async {
  final regular = await rootBundle.load('assets/fonts/Quicksand-Regular.ttf');
  final bold    = await rootBundle.load('assets/fonts/Quicksand-Bold.ttf');
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
  );
}

pw.Widget pdfWhiteBackground(pw.Context context) => pw.FullPage(
  ignoreMargins: true,
  child: pw.Container(color: PdfColors.white),
);

// Quicksand has no glyph for a phone symbol, and the pdf package draws a
// missing glyph as nothing at all — so the footer says "Ph" rather than
// shipping an invisible ☎ on every page of every document.
pw.Widget pdfPageFooter(pw.Context context, BusinessInfoData? business) {
  final name  = business?.name ?? BrandConfig.milano.appName;
  final phone = business?.phone;
  final label = (phone != null && phone.isNotEmpty)
      ? '$name · Ph $phone   ·   Page ${context.pageNumber} of ${context.pagesCount}'
      : '$name   ·   Page ${context.pageNumber} of ${context.pagesCount}';
  return pw.Column(
    children: [
      pw.Divider(thickness: 0.5, color: kPdfGold),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  );
}
