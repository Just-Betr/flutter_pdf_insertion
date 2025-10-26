import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import '../models/pdf_template.dart';

/// Loads PDF templates from bundled assets and prepares background images.
class PdfTemplateLoader {
  PdfTemplateLoader({final AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  PdfTemplate? _cachedTemplate;

  Future<PdfTemplate> load(final PdfTemplateConfig config) async {
    if (_cachedTemplate != null) {
      return _cachedTemplate!;
    }

    final assetData = await _bundle.load(config.assetPath);
    final bytes = assetData.buffer.asUint8List();
    final rasters = await Printing.raster(bytes, dpi: config.rasterDpi).toList();

    final sortedPages = List<PdfTemplatePageConfig>.from(config.pages)..sort((final a, final b) => a.page.compareTo(b.page));

    final pages = <PdfTemplatePage>[];
    for (final pageConfig in sortedPages) {
      if (pageConfig.page < 0 || pageConfig.page >= rasters.length) {
        throw StateError('Template missing page ${pageConfig.page + 1}');
      }
      final raster = rasters[pageConfig.page];

      final pageFormat = pageConfig.pageFormat ?? PdfPageFormat.letter;
      final backgroundBytes = await raster.toPng();
      final backgroundImage = MemoryImage(backgroundBytes);

      final fieldsForPage = pageConfig.fields
          .where((final field) => field.pageIndex == pageConfig.page)
          .toList(growable: false);

      pages.add(
        PdfTemplatePage(
          index: pageConfig.page,
          pageFormat: pageFormat,
          fields: fieldsForPage,
          background: backgroundImage,
        ),
      );
    }

    final resolvedName = (config.pdfName ?? '').trim().isEmpty
        ? inferPdfNameFromAsset(config.assetPath)
        : config.pdfName!.trim();

    final template = PdfTemplate(
      assetPath: config.assetPath,
      name: resolvedName,
      rasterDpi: config.rasterDpi,
      pages: pages,
    );
    _cachedTemplate = template;
    return template;
  }
}
