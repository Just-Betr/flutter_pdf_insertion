import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../models/pdf_form_data.dart';
import '../services/pdf_service.dart';

abstract interface class PdfFormController {
  Future<Uint8List> generatePdfBytes(PdfFormData data);

  Future<void> sharePdf(PdfFormData data);
  Future<void> previewPdf(PdfFormData data);
}

// This is the default implementation of PdfFormController.
// It is the connection between the UI and the PDF generation service.
// Following a simple MVC pattern.
class DefaultPdfFormController implements PdfFormController {
  DefaultPdfFormController({required PdfGenerationService pdfService}) : _pdfService = pdfService;

  final PdfGenerationService _pdfService;

  @override
  Future<Uint8List> generatePdfBytes(final PdfFormData data) {
    return _pdfService.buildFilledPdf(data);
  }

  @override
  Future<void> sharePdf(final PdfFormData data) async {
    final pdfBytes = await generatePdfBytes(data);
    final assetPath = _pdfService.templateAssetPath;
    final templateName = _pdfService.templateName.trim();
    final assetName = _extractAssetName(assetPath);
    final dotIndex = assetName.lastIndexOf('.');
    final fallbackBase = dotIndex > 0 ? assetName.substring(0, dotIndex) : assetName;
    final extension = dotIndex > 0 ? assetName.substring(dotIndex) : '.pdf';
    final baseName = _sanitizeBaseName(templateName.isEmpty ? fallbackBase : templateName);

    final timestamp = _formatTimestamp(DateTime.now());
    final filename = '${baseName}_$timestamp$extension';
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  String _formatTimestamp(final DateTime datetime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final year = datetime.year.toString().padLeft(4, '0');
    final month = twoDigits(datetime.month);
    final day = twoDigits(datetime.day);
    final hour = twoDigits(datetime.hour);
    final minute = twoDigits(datetime.minute);
    final second = twoDigits(datetime.second);
    final buffer = StringBuffer()
      ..write(year)
      ..write(month)
      ..write(day)
      ..write('_')
      ..write(hour)
      ..write(minute)
      ..write(second);
    return buffer.toString();
  }

  String _extractAssetName(String assetPath) {
    final normalized = assetPath.replaceAll('\\', '/');
    final segments = normalized.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
    if (segments.isEmpty) {
      return assetPath;
    }
    return segments.last;
  }

  String _sanitizeBaseName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'document';
    }
    final collapsedWhitespace = trimmed.replaceAll(RegExp(r'\s+'), '_');
    return collapsedWhitespace;
  }

  @override
  Future<void> previewPdf(final PdfFormData data) {
    return Printing.layoutPdf(onLayout: (_) => generatePdfBytes(data));
  }
}
