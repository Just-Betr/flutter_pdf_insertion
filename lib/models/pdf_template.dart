import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

enum PdfFieldType { text, signature }

enum PdfMeasurementUnit { fraction, points }

enum PdfTextAlignment { start, center, end }

class PdfFieldBinding {
  const PdfFieldBinding._(this.value);

  final String value;

  factory PdfFieldBinding(String name) => PdfFieldBinding.named(name);

  factory PdfFieldBinding.named(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('PdfFieldBinding name cannot be empty');
    }
    return PdfFieldBinding._(normalized);
  }

  @override
  bool operator ==(Object other) => other is PdfFieldBinding && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PdfFieldBinding($value)';
}

class PdfFieldConfig {
  const PdfFieldConfig({
    required this.binding,
    required this.type,
    required this.pageIndex,
    required this.x,
    required this.y,
    this.width,
    this.height,
    this.fontSize,
    this.positionUnit = PdfMeasurementUnit.fraction,
    this.sizeUnit = PdfMeasurementUnit.fraction,
    this.textAlignment = PdfTextAlignment.start,
    this.maxLines = 1,
    this.allowWrap = false,
    this.shrinkToFit = true,
    this.uppercase = false,
    this.isRequired = true,
  });

  final PdfFieldBinding binding;
  final PdfFieldType type;
  final int pageIndex;
  final double x;
  final double y;
  final double? width;
  final double? height;
  final double? fontSize;
  final PdfMeasurementUnit positionUnit;
  final PdfMeasurementUnit sizeUnit;
  final PdfTextAlignment textAlignment;
  final int? maxLines;
  final bool allowWrap;
  final bool shrinkToFit;
  final bool uppercase;
  final bool isRequired;
}

class PdfTemplatePageConfig {
  const PdfTemplatePageConfig({required this.page, required this.fields, this.pageFormat});

  final int page;
  final List<PdfFieldConfig> fields;
  final PdfPageFormat? pageFormat;
}

class PdfTemplateConfig {
  const PdfTemplateConfig({required this.assetPath, required this.pages, this.pdfName, this.rasterDpi = 144});

  final String assetPath;
  final List<PdfTemplatePageConfig> pages;
  final String? pdfName;
  final double rasterDpi;
}

class PdfTemplate {
  PdfTemplate({required this.assetPath, required this.name, required this.rasterDpi, required this.pages});

  final String assetPath;
  final String name;
  final double rasterDpi;
  final List<PdfTemplatePage> pages;
}

class PdfTemplatePage {
  PdfTemplatePage({required this.index, required this.pageFormat, required this.fields, this.background});

  final int index;
  final PdfPageFormat pageFormat;
  final List<PdfFieldConfig> fields;
  final MemoryImage? background;
}

class PdfTemplateConfigBuilder {
  PdfTemplateConfigBuilder({required String assetPath}) : _assetPath = assetPath;

  String _assetPath;
  String? _pdfName;
  double _rasterDpi = 144;
  final List<PdfTemplatePageBuilder> _pageBuilders = [];

  PdfTemplateConfigBuilder assetPath(String value) {
    _assetPath = value;
    return this;
  }

  PdfTemplateConfigBuilder pdfName(String value) {
    _pdfName = value;
    return this;
  }

  PdfTemplateConfigBuilder rasterDpi(double value) {
    _rasterDpi = value;
    return this;
  }

  PdfTemplatePageBuilder addPage({required int index, PdfPageFormat? pageFormat}) {
    final builder = PdfTemplatePageBuilder(page: index, pageFormat: pageFormat);
    _pageBuilders.add(builder);
    return builder;
  }

  PdfTemplateConfigBuilder page({
    required int index,
    PdfPageFormat? pageFormat,
    void Function(PdfTemplatePageBuilder page)? build,
  }) {
    final builder = PdfTemplatePageBuilder(page: index, pageFormat: pageFormat);
    if (build != null) {
      build(builder);
    }
    _pageBuilders.add(builder);
    return this;
  }

  PdfTemplateConfig build() {
    final pages = _pageBuilders.map((builder) => builder.build()).toList(growable: false);
    return PdfTemplateConfig(
      assetPath: _assetPath,
      pdfName: _pdfName ?? inferPdfNameFromAsset(_assetPath),
      pages: List.unmodifiable(pages),
      rasterDpi: _rasterDpi,
    );
  }
}

class PdfTemplatePageBuilder {
  PdfTemplatePageBuilder({required this.page, PdfPageFormat? pageFormat})
    : _pageFormat = pageFormat ?? PdfPageFormat.letter;

  final int page;
  PdfPageFormat _pageFormat;
  final List<PdfFieldConfig> _fields = [];

  PdfTemplatePageBuilder pageFormat(PdfPageFormat value) {
    _pageFormat = value;
    return this;
  }

  PdfTemplatePageBuilder addField(PdfFieldConfig field) {
    if (field.pageIndex != page) {
      throw ArgumentError('Field pageIndex ${field.pageIndex} does not match page $page');
    }
    _fields.add(field);
    return this;
  }

  PdfTemplatePageBuilder addTextField({
    required PdfFieldBinding binding,
    required double x,
    required double y,
    double? width,
    double? height,
    double? fontSize,
    PdfMeasurementUnit positionUnit = PdfMeasurementUnit.fraction,
    PdfMeasurementUnit sizeUnit = PdfMeasurementUnit.fraction,
    PdfTextAlignment? textAlignment,
    int? maxLines,
    bool allowWrap = false,
    bool? shrinkToFit,
    bool uppercase = false,
    bool isRequired = true,
  }) {
    _fields.add(
      PdfFieldConfig(
        binding: binding,
        type: PdfFieldType.text,
        pageIndex: page,
        x: x,
        y: y,
        width: width,
        height: height,
        fontSize: fontSize,
        positionUnit: positionUnit,
        sizeUnit: sizeUnit,
        textAlignment: textAlignment ?? PdfTextAlignment.start,
        maxLines: maxLines,
        allowWrap: allowWrap,
        shrinkToFit: shrinkToFit ?? true,
        uppercase: uppercase,
        isRequired: isRequired,
      ),
    );
    return this;
  }

  PdfTemplatePageBuilder addSignatureField({
    required PdfFieldBinding binding,
    required double x,
    required double y,
    double? width,
    double? height,
    PdfMeasurementUnit positionUnit = PdfMeasurementUnit.fraction,
    PdfMeasurementUnit sizeUnit = PdfMeasurementUnit.fraction,
    bool isRequired = true,
  }) {
    _fields.add(
      PdfFieldConfig(
        binding: binding,
        type: PdfFieldType.signature,
        pageIndex: page,
        x: x,
        y: y,
        width: width,
        height: height,
        positionUnit: positionUnit,
        sizeUnit: sizeUnit,
        isRequired: isRequired,
      ),
    );
    return this;
  }

  PdfTemplatePageConfig build() {
    return PdfTemplatePageConfig(page: page, fields: List.unmodifiable(_fields), pageFormat: _pageFormat);
  }

  PdfTemplatePageBuilder textField({
    required PdfFieldBinding binding,
    required double x,
    required double y,
    double? width,
    double? height,
    double fontSize = 12.0,
    PdfMeasurementUnit positionUnit = PdfMeasurementUnit.points,
    PdfMeasurementUnit sizeUnit = PdfMeasurementUnit.points,
    PdfTextAlignment? textAlignment,
    int? maxLines,
    bool allowWrap = false,
    bool? shrinkToFit,
    bool uppercase = false,
    bool isRequired = true,
  }) {
    return addTextField(
      binding: binding,
      x: x,
      y: y,
      width: width,
      height: height,
      fontSize: fontSize,
      positionUnit: positionUnit,
      sizeUnit: sizeUnit,
      textAlignment: textAlignment,
      maxLines: maxLines,
      allowWrap: allowWrap,
      shrinkToFit: shrinkToFit,
      uppercase: uppercase,
      isRequired: isRequired,
    );
  }

  PdfTemplatePageBuilder signatureField({
    PdfFieldBinding? binding,
    required double x,
    required double y,
    double? width,
    double? height,
    PdfMeasurementUnit positionUnit = PdfMeasurementUnit.points,
    PdfMeasurementUnit sizeUnit = PdfMeasurementUnit.points,
    bool isRequired = true,
  }) {
    return addSignatureField(
      binding: binding ?? PdfFieldBinding.named('signature'),
      x: x,
      y: y,
      width: width,
      height: height,
      positionUnit: positionUnit,
      sizeUnit: sizeUnit,
      isRequired: isRequired,
    );
  }
}

String inferPdfNameFromAsset(String assetPath) {
  final normalized = assetPath.replaceAll('\\', '/');
  final segments = normalized.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
  if (segments.isEmpty) {
    return assetPath;
  }
  final filename = segments.last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) {
    return filename;
  }
  return filename.substring(0, dotIndex);
}
