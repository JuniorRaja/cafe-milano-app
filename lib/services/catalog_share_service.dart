import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../app.dart' show kDefaultLogoAsset;
import '../database/app_database.dart';

enum CatalogShareFormat { pdf, image, text }

const _kRowHeight = 56.0;
const _kImageWidth = 480.0;

String _formatPrice(Product product) {
  if (product.price == null) {
    return product.unit != null ? 'per ${product.unit}' : '-';
  }
  final price = product.price!;
  final text =
      price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  return product.unit != null ? '₹$text / ${product.unit}' : '₹$text';
}

Future<pw.ThemeData> _loadTheme() async {
  final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
  );
}

Future<pw.MemoryImage?> _loadLogo(BusinessInfoData? business) async {
  try {
    if (business?.logoPath != null) {
      final bytes = await File(business!.logoPath!).readAsBytes();
      return pw.MemoryImage(bytes);
    }
    final asset = await rootBundle.load(kDefaultLogoAsset);
    return pw.MemoryImage(asset.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

Future<Map<int, pw.MemoryImage>> _loadProductPhotos(List<Product> products) async {
  final result = <int, pw.MemoryImage>{};
  for (final product in products) {
    if (product.photoPath == null) continue;
    try {
      final bytes = await File(product.photoPath!).readAsBytes();
      result[product.id] = pw.MemoryImage(bytes);
    } catch (_) {
      // Skip products whose photo file no longer exists on disk.
    }
  }
  return result;
}

pw.Widget _whiteBackground(pw.Context context) {
  return pw.FullPage(
    ignoreMargins: true,
    child: pw.Container(color: PdfColors.white),
  );
}

pw.Widget _buildLetterhead(BusinessInfoData? business, pw.MemoryImage? logo) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      if (logo != null)
        pw.Container(
          width: 56,
          height: 56,
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.ClipRRect(
            horizontalRadius: 8,
            verticalRadius: 8,
            child: pw.Image(logo, fit: pw.BoxFit.cover),
          ),
        ),
      pw.Text(
        business?.name ?? 'Cafe Milano',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      if (business?.address != null && business!.address!.isNotEmpty)
        pw.Text(business.address!, style: const pw.TextStyle(fontSize: 10)),
      if (business?.phone != null && business!.phone!.isNotEmpty)
        pw.Text('Phone: ${business.phone}', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 6),
      pw.Text(
        'Product Catalog',
        style: pw.TextStyle(fontSize: 13, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 1, color: PdfColors.grey400),
    ],
  );
}

pw.Widget _buildProductRow(Product product, pw.MemoryImage? photo) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300)),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 40,
          height: 40,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(4),
            color: PdfColors.grey200,
          ),
          child: photo != null
              ? pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(photo, fit: pw.BoxFit.cover),
                )
              : null,
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Text(
            product.name,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(_formatPrice(product), style: const pw.TextStyle(fontSize: 12)),
      ],
    ),
  );
}

Future<Uint8List> _buildPdfBytes({
  required BusinessInfoData? business,
  required List<Product> products,
}) async {
  final theme = await _loadTheme();
  final logo = await _loadLogo(business);
  final photos = await _loadProductPhotos(products);

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        buildBackground: _whiteBackground,
      ),
      header: (context) =>
          context.pageNumber == 1 ? _buildLetterhead(business, logo) : pw.SizedBox(),
      build: (context) => [
        for (final product in products) _buildProductRow(product, photos[product.id]),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> _buildImagePdfBytes({
  required BusinessInfoData? business,
  required List<Product> products,
}) async {
  final theme = await _loadTheme();
  final logo = await _loadLogo(business);
  final photos = await _loadProductPhotos(products);

  const headerHeight = 160.0;
  const margin = 20.0;
  final pageHeight = headerHeight + products.length * _kRowHeight + margin * 2;

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat(_kImageWidth, pageHeight, marginAll: margin),
        buildBackground: _whiteBackground,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildLetterhead(business, logo),
          for (final product in products) _buildProductRow(product, photos[product.id]),
        ],
      ),
    ),
  );
  return doc.save();
}

Future<void> shareCatalogAsPdf({
  required BusinessInfoData? business,
  required List<Product> products,
}) async {
  final bytes = await _buildPdfBytes(business: business, products: products);
  await Printing.sharePdf(bytes: bytes, filename: 'cafe-milano-catalog.pdf');
}

Future<void> shareCatalogAsImage({
  required BusinessInfoData? business,
  required List<Product> products,
}) async {
  final pdfBytes = await _buildImagePdfBytes(business: business, products: products);
  final page = await Printing.raster(pdfBytes, dpi: 150).first;
  final pngBytes = await page.toPng();

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/cafe-milano-catalog-${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(pngBytes);

  await Share.shareXFiles([XFile(file.path)], text: 'Cafe Milano Catalog');
}

String _buildCatalogText({
  required BusinessInfoData? business,
  required List<Product> products,
}) {
  final buf = StringBuffer();
  buf.writeln('🍽️ ${business?.name ?? 'Cafe Milano'} — Product Catalog');
  if (business?.address != null && business!.address!.isNotEmpty) {
    buf.writeln(business.address!);
  }
  if (business?.phone != null && business!.phone!.isNotEmpty) {
    buf.writeln('Phone: ${business.phone}');
  }
  buf.writeln();

  final maxNameLen = products.map((p) => p.name.length).fold(0, max);
  for (final product in products) {
    buf.writeln('${product.name.padRight(maxNameLen + 2)}${_formatPrice(product)}');
  }

  return buf.toString().trim();
}

Future<void> shareCatalogAsText({
  required BusinessInfoData? business,
  required List<Product> products,
}) async {
  await Share.share(_buildCatalogText(business: business, products: products));
}
