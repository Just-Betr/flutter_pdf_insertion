import 'dart:typed_data';

import '../models/pdf_form_data.dart';
import '../models/pdf_template.dart';
import 'pdf_exporters.dart';

abstract interface class PdfGenerationService {
  Future<Uint8List> buildFilledPdf(PdfFormData data);
  String get templateAssetPath;
  String get templateName;
}

// Default implementation of PdfGenerationService.
// The controller uses this service as a connection between the UI and the PDF exporter.
class DefaultPdfGenerationService implements PdfGenerationService {
  DefaultPdfGenerationService({required PdfExporter exporter, required String templateAssetPath, String? templateName})
    : _exporter = exporter,
      _templateAssetPath = templateAssetPath,
      _templateName = _resolveTemplateName(explicitName: templateName, assetPath: templateAssetPath);

  factory DefaultPdfGenerationService.singleton() => _instance;

  static final PdfTemplateConfig _defaultConfig = PdfExporterFactory.defaultTemplateConfig;

  static final DefaultPdfGenerationService _instance = DefaultPdfGenerationService(
    exporter: PdfExporterFactory.createSimpleExporter(config: _defaultConfig),
    templateAssetPath: _defaultConfig.assetPath,
    templateName: _defaultConfig.pdfName,
  );

  final PdfExporter _exporter;
  final String _templateAssetPath;
  final String _templateName;

  @override
  Future<Uint8List> buildFilledPdf(PdfFormData data) {
    return _exporter.export(data);
  }

  @override
  String get templateAssetPath => _templateAssetPath;

  @override
  String get templateName => _templateName;

  static String _resolveTemplateName({String? explicitName, required String assetPath}) {
    final candidate = explicitName?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return inferPdfNameFromAsset(assetPath);
  }
}

class PdfGenerationServiceFactory {
  const PdfGenerationServiceFactory._();

  static PdfGenerationService createDefault() => DefaultPdfGenerationService.singleton();
}
