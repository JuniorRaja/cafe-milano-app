import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../app.dart' show kDefaultLogoAsset;
import '../database/app_database.dart';
import 'category_emoji.dart';

// Brand colours as PDF equivalents of kBrandGold / kBrandBrown from app.dart
const _kGold  = PdfColor(1.0, 192 / 255, 0.0);         // 0xFFFFC000
const _kBrown = PdfColor(74 / 255, 44 / 255, 42 / 255); // 0xFF4A2C2A

enum CatalogShareFormat { pdf, text }

String _formatDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatPrice(Product product) {
  if (product.price == null) {
    return product.unit != null ? 'per ${product.unit}' : '-';
  }
  final price = product.price!;
  final text = price == price.roundToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);
  return product.unit != null ? '₹$text / ${product.unit}' : '₹$text';
}

Future<pw.ThemeData> _loadTheme() async {
  final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
  final bold    = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
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
    } catch (_) {}
  }
  return result;
}

pw.Widget _whiteBackground(pw.Context context) => pw.FullPage(
  ignoreMargins: true,
  child: pw.Container(color: PdfColors.white),
);

// ---------------------------------------------------------------------------
// Groups products by active category (in sortOrder), then uncategorised last.
// Products whose categoryId matches no active category fall into Others.
// ---------------------------------------------------------------------------
List<({String? name, String emoji, List<Product> products})> _groupProducts(
  List<Product> products,
  List<Category> categories,
) {
  final activeCatIds = {for (final c in categories) c.id};
  final grouped = <int?, List<Product>>{};
  for (final p in products) {
    final key = (p.categoryId != null && activeCatIds.contains(p.categoryId))
        ? p.categoryId
        : null;
    grouped.putIfAbsent(key, () => []).add(p);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }

  final result = <({String? name, String emoji, List<Product> products})>[];
  for (final cat in categories) {
    final prods = grouped[cat.id];
    if (prods != null && prods.isNotEmpty) {
      result.add((name: cat.name, emoji: emojiFor(cat.name), products: prods));
    }
  }
  final others = grouped[null];
  if (others != null && others.isNotEmpty) {
    result.add((name: null, emoji: '🍽️', products: others));
  }
  return result;
}

// ---------------------------------------------------------------------------
// PDF widgets
// ---------------------------------------------------------------------------

pw.Widget _buildCoverPage(BusinessInfoData? business, pw.MemoryImage? logo) {
  final name    = business?.name ?? 'Cafe Milano';
  final address = business?.address;
  final phone   = business?.phone;

  return pw.Center(
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null)
          pw.Container(
            width: 120,
            height: 120,
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.ClipRRect(
              horizontalRadius: 12,
              verticalRadius: 12,
              child: pw.Image(logo, fit: pw.BoxFit.cover),
            ),
          ),
        pw.Text(
          name,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _kBrown),
        ),
        if (address != null && address.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
        if (phone != null && phone.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(phone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Product Catalog',
          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, color: _kGold),
        ),
      ],
    ),
  );
}

pw.Widget _buildCategoryHeader(String label, String emoji) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 3, color: _kGold),
        pw.SizedBox(height: 6),
        pw.Text(
          '$emoji $label',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _kBrown),
        ),
      ],
    ),
  );
}

pw.Widget _buildPhotoBox(Product product, pw.MemoryImage? photo, {double size = 72}) {
  if (photo != null) {
    return pw.Container(
      width: size,
      height: size,
      child: pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Image(photo, fit: pw.BoxFit.cover),
      ),
    );
  }
  final letter = product.name.isNotEmpty ? product.name[0].toUpperCase() : '?';
  return pw.Container(
    width: size,
    height: size,
    decoration: pw.BoxDecoration(
      color: _kBrown,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Center(
      child: pw.Text(
        letter,
        style: pw.TextStyle(fontSize: size * 0.32, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    ),
  );
}

pw.Widget _buildProductCard(Product product, pw.MemoryImage? photo, String? categoryName) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _buildPhotoBox(product, photo),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                product.name,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              if (categoryName != null)
                pw.Text(categoryName, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              if (product.unit != null)
                pw.Text(product.unit!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.Text(
          _formatPrice(product),
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kBrown),
        ),
      ],
    ),
  );
}

pw.Widget _buildProductList(
  List<Product> products,
  Map<int, pw.MemoryImage> photos,
  String? categoryName,
) {
  return pw.Column(
    children: products.map((p) => _buildProductCard(p, photos[p.id], categoryName)).toList(),
  );
}

pw.Widget _buildContentFooter(pw.Context context, BusinessInfoData? business) {
  final name  = business?.name ?? 'Cafe Milano';
  final phone = business?.phone;
  final label = (phone != null && phone.isNotEmpty)
      ? '$name · ☎ $phone   ·   Page ${context.pageNumber} of ${context.pagesCount}'
      : '$name   ·   Page ${context.pageNumber} of ${context.pagesCount}';
  return pw.Column(
    children: [
      pw.Divider(thickness: 0.5, color: _kGold),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

Future<Uint8List> _buildPdfBytes({
  required BusinessInfoData? business,
  required List<Product> products,
  required List<Category> categories,
}) async {
  final theme  = await _loadTheme();
  final logo   = await _loadLogo(business);
  final photos = await _loadProductPhotos(products);
  final groups = _groupProducts(products, categories);

  final doc = pw.Document(theme: theme);

  // Cover page — no footer
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        buildBackground: _whiteBackground,
      ),
      build: (context) => _buildCoverPage(business, logo),
    ),
  );

  // Content pages — footer on every page
  if (groups.isNotEmpty) {
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          buildBackground: _whiteBackground,
        ),
        footer: (context) => _buildContentFooter(context, business),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (final group in groups) {
            widgets.add(_buildCategoryHeader(group.name ?? 'Others', group.emoji));
            widgets.add(_buildProductList(group.products, photos, group.name));
          }
          return widgets;
        },
      ),
    );
  }

  return doc.save();
}

Future<void> shareCatalogAsPdf({
  required BusinessInfoData? business,
  required List<Product> products,
  required List<Category> categories,
}) async {
  final bytes = await _buildPdfBytes(
    business: business,
    products: products,
    categories: categories,
  );
  await Printing.sharePdf(bytes: bytes, filename: 'cafe-milano-catalog.pdf');
}

String _buildCatalogText({
  required BusinessInfoData? business,
  required List<Product> products,
  required List<Category> categories,
}) {
  final buf  = StringBuffer();
  final name = business?.name ?? 'Cafe Milano';
  buf.writeln('🍽️ $name — Product Catalog');
  final phone = business?.phone;
  if (phone != null && phone.isNotEmpty) buf.writeln('☎ $phone');
  buf.writeln('Prices as of ${_formatDate(DateTime.now())}');

  for (final group in _groupProducts(products, categories)) {
    buf.writeln();
    buf.writeln('${group.emoji} ${group.name ?? 'Others'}');
    for (final p in group.products) {
      buf.writeln('· ${p.name} — ${_formatPrice(p)}');
    }
  }
  return buf.toString().trim();
}

Future<void> shareCatalogAsText({
  required BusinessInfoData? business,
  required List<Product> products,
  required List<Category> categories,
}) async {
  await Share.share(
    _buildCatalogText(business: business, products: products, categories: categories),
  );
}
