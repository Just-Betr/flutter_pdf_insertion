import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import '../models/pdf_form_data.dart';
import '../models/pdf_template.dart';
import 'pdf_template_loader.dart';

/// Abstract PDF exporter defining the strategy for rendering a document.
abstract class PdfExporter {
  Future<Uint8List> export(final PdfFormData data);
}

/// Factory that produces the concrete [PdfExporter] implementation.
class PdfExporterFactory {
  const PdfExporterFactory._();

  static PdfTemplateConfig get defaultTemplateConfig => _defaultTemplateConfig;

  static PdfExporter createSimpleExporter({final PdfTemplateConfig? config, final PdfTemplateLoader? loader}) {
    final resolvedConfig = config ?? _defaultTemplateConfig;
    return _TemplatePdfExporter(loader: loader ?? PdfTemplateLoader(), config: resolvedConfig);
  }
}

/// Asset path for the bundled PDF template used by the default exporter.
const String kDefaultTemplateAssetPath = 'assets/example.pdf';

/// Default template configuration describing where each field should be rendered.
final PdfTemplateConfig _defaultTemplateConfig = _buildExampleTemplateConfig();

PdfTemplateConfig _buildExampleTemplateConfig() {
  final builder = PdfTemplateConfigBuilder(assetPath: kDefaultTemplateAssetPath)
    ..pdfName('example')
    ..rasterDpi(144);

  final firstName = PdfFieldBinding.named('firstName');
  final lastName = PdfFieldBinding.named('lastName');
  final isKewl = PdfFieldBinding.named('isKewl');
  final signature = PdfFieldBinding.named('signature');
  final currentDate = PdfFieldBinding.named('currentDate');

  builder
      .page(
        index: 0,
        build: (final page) {
          page
            ..textField(binding: firstName, x: 135.375, y: 192.0, width: 102.0, height: 18.0, maxLines: 1)
            ..textField(binding: lastName, x: 133.875, y: 219.75, width: 100.5, height: 18.0, maxLines: 1);
        },
      )
      .page(
        index: 1,
        build: (final page) {
          page
            ..textField(binding: isKewl, x: 92.374, y: 106.504, width: 7.748, height: 9.503, isRequired: false)
            ..signatureField(binding: signature, x: 129.619, y: 164.501, width: 193.747, height: 20.002)
            ..textField(binding: currentDate, x: 359.629, y: 165.0, width: 117.502, height: 18.0);
        },
      );

  return builder.build();
}

class _TemplatePdfExporter implements PdfExporter {
  _TemplatePdfExporter({required final PdfTemplateLoader loader, required final PdfTemplateConfig config})
    : _loader = loader,
      _config = config;

  final PdfTemplateLoader _loader;
  final PdfTemplateConfig _config;
  PdfTemplate? _template;

  @override
  Future<Uint8List> export(final PdfFormData data) async {
    _template ??= await _loader.load(_config);
    final template = _template!;

    final signatureImages = <String, MemoryImage?>{};
    if (data.signatureStrokes.isNotEmpty) {
      final targetHeights = <double>{};
      for (final page in template.pages) {
        for (final field in page.fields.where((final field) => field.type == PdfFieldType.signature)) {
          final targetHeight =
              _resolveSize(value: field.height, axisExtent: page.pageFormat.height, unit: field.sizeUnit) ??
              page.pageFormat.height * 0.15;
          targetHeights.add(targetHeight);
        }
      }

      for (final targetHeight in targetHeights) {
        final bytes = await _renderSignatureAsPng(
          strokes: data.signatureStrokes,
          canvasSize: data.signatureCanvasSize,
          targetHeight: targetHeight,
        );
        signatureImages[_signatureCacheKey(targetHeight)] = bytes.isEmpty ? null : MemoryImage(bytes);
      }
    }
    final timestamp = DateTime.now();

    final doc = Document();
    for (final page in template.pages) {
      doc.addPage(
        Page(
          pageFormat: page.pageFormat,
          margin: EdgeInsets.zero,
          build: (final context) =>
              _buildPage(page: page, data: data, signatureImages: signatureImages, timestamp: timestamp),
        ),
      );
    }

    return doc.save();
  }

  Widget _buildPage({
    required final PdfTemplatePage page,
    required final PdfFormData data,
    required final Map<String, MemoryImage?> signatureImages,
    required final DateTime timestamp,
  }) {
    final children = <Widget>[];
    if (page.background != null) {
      children.add(Positioned.fill(child: Image(page.background!, fit: BoxFit.cover)));
    }

    for (final field in page.fields) {
      children.add(
        _buildField(page: page, field: field, data: data, signatureImages: signatureImages, timestamp: timestamp),
      );
    }

    return Stack(children: children);
  }

  Widget _buildField({
    required final PdfTemplatePage page,
    required final PdfFieldConfig field,
    required final PdfFormData data,
    required final Map<String, MemoryImage?> signatureImages,
    required final DateTime timestamp,
  }) {
    final pageWidth = page.pageFormat.width;
    final pageHeight = page.pageFormat.height;
    final left = _resolveCoordinate(value: field.x, axisExtent: pageWidth, unit: field.positionUnit);
    final top = _resolveCoordinate(value: field.y, axisExtent: pageHeight, unit: field.positionUnit);
    final width = _resolveSize(value: field.width, axisExtent: pageWidth, unit: field.sizeUnit);
    final height = _resolveSize(value: field.height, axisExtent: pageHeight, unit: field.sizeUnit);

    switch (field.type) {
      case PdfFieldType.text:
        final rawText = _resolveText(binding: field.binding, data: data, timestamp: timestamp);
        final resolvedText = field.uppercase ? rawText.toUpperCase() : rawText;
        if (!field.isRequired && resolvedText.trim().isEmpty) {
          return Positioned(
            left: left,
            top: top,
            child: SizedBox(width: width, height: height),
          );
        }
        final maxLines = field.allowWrap ? field.maxLines : (field.maxLines ?? 1);
        final textWidget = Text(
          resolvedText,
          style: TextStyle(fontSize: field.fontSize ?? 12, fontWeight: FontWeight.normal, color: PdfColors.black),
          textAlign: _mapTextAlign(alignment: field.textAlignment),
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        );

        final wrapped = _wrapTextWidget(textWidget: textWidget, width: width, height: height, field: field);

        return Positioned(left: left, top: top, child: wrapped);

      case PdfFieldType.signature:
        final targetHeight = height ?? pageHeight * 0.15;
        final signatureKey = _signatureCacheKey(targetHeight);
        final signatureImage = signatureImages[signatureKey];
        final hasSignature = signatureImage != null;
        final boxWidth = width ?? pageWidth * 0.45;
        final boxHeight = height ?? pageHeight * 0.15;
        final border = Border.all(color: PdfColors.grey500, width: 1);

        if (!hasSignature && !field.isRequired) {
          return Positioned(
            left: left,
            top: top,
            child: SizedBox(width: boxWidth, height: boxHeight),
          );
        }

        final placeholder = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: PdfColor.fromInt(0xFFF2F4F7)),
          child: Text(
            'Signature not captured',
            style: TextStyle(fontSize: (field.fontSize ?? 12), color: PdfColors.grey600),
          ),
        );

        final padding = boxHeight <= 0 ? 0.0 : min(6.0, max(0.0, boxHeight * 0.1));
        final availableWidth = (boxWidth - padding * 2).clamp(0.0, double.infinity);
        final availableHeight = (boxHeight - padding * 2).clamp(0.0, double.infinity);

        final signatureWidget = hasSignature && availableWidth > 0 && availableHeight > 0
            ? Container(
                padding: padding > 0 ? EdgeInsets.all(padding) : EdgeInsets.zero,
                alignment: Alignment.center,
                child: Image(signatureImage, width: availableWidth, height: availableHeight, fit: BoxFit.contain),
              )
            : placeholder;

        return Positioned(
          left: left,
          top: top,
          child: Container(
            width: boxWidth,
            height: boxHeight,
            decoration: hasSignature ? null : BoxDecoration(border: border),
            child: signatureWidget,
          ),
        );
    }
  }

  double _resolveCoordinate({required final double value, required final double axisExtent, required final PdfMeasurementUnit unit}) {
    switch (unit) {
      case PdfMeasurementUnit.fraction:
        return value * axisExtent;
      case PdfMeasurementUnit.points:
        return value;
    }
  }

  double? _resolveSize({required final double? value, required final double axisExtent, required final PdfMeasurementUnit unit}) {
    if (value == null) {
      return null;
    }
    switch (unit) {
      case PdfMeasurementUnit.fraction:
        return value * axisExtent;
      case PdfMeasurementUnit.points:
        return value;
    }
  }

  String _resolveText({required final PdfFieldBinding binding, required final PdfFormData data, required final DateTime timestamp}) {
    switch (binding.value) {
      case 'firstName':
        return _safeValue(value: data.firstName);
      case 'lastName':
        return _safeValue(value: data.lastName);
      case 'isKewl':
        return data.isKewl ? 'X' : '';
      case 'currentDate':
        return _formatDate(value: timestamp);
      case 'signature':
        return '';
      default:
        final dynamic value = data.additionalValues[binding.value];
        if (value == null) {
          return '';
        }
        if (value is bool) {
          return value ? 'X' : '';
        }
        return _safeValue(value: value.toString());
    }
  }

  Alignment _mapAlignment({required final PdfTextAlignment alignment}) {
    switch (alignment) {
      case PdfTextAlignment.start:
        return Alignment.topLeft;
      case PdfTextAlignment.center:
        return Alignment.topCenter;
      case PdfTextAlignment.end:
        return Alignment.topRight;
    }
  }

  TextAlign _mapTextAlign({required final PdfTextAlignment alignment}) {
    switch (alignment) {
      case PdfTextAlignment.start:
        return TextAlign.left;
      case PdfTextAlignment.center:
        return TextAlign.center;
      case PdfTextAlignment.end:
        return TextAlign.right;
    }
  }

  Widget _wrapTextWidget({
    required final Widget textWidget,
    required final double? width,
    required final double? height,
    required final PdfFieldConfig field,
  }) {
    if (width == null && height == null) {
      return textWidget;
    }

    final alignment = _mapAlignment(alignment: field.textAlignment);

    if (field.allowWrap && !field.shrinkToFit) {
      return Container(width: width, height: height, alignment: alignment, child: textWidget);
    }

    final child = field.shrinkToFit
        ? FittedBox(alignment: alignment, fit: BoxFit.scaleDown, child: textWidget)
        : textWidget;

    return Container(width: width, height: height, alignment: alignment, child: child);
  }

  String _safeValue({required final String value}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '' : trimmed;
  }

  String _formatDate({required final DateTime value}) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$month/$day/$year';
  }
}

String _signatureCacheKey(final double value) => value.toStringAsFixed(3);

Future<Uint8List> _renderSignatureAsPng({
  required final List<List<Offset>> strokes,
  required final Size canvasSize,
  final double? targetHeight,
}) async {
  if (strokes.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
    return Uint8List(0);
  }

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final stroke in strokes) {
    for (final point in stroke) {
      final dx = point.dx;
      final dy = point.dy;
      if (dx < minX) minX = dx;
      if (dy < minY) minY = dy;
      if (dx > maxX) maxX = dx;
      if (dy > maxY) maxY = dy;
    }
  }

  if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
    return Uint8List(0);
  }

  const margin = 12.0;
  final contentWidth = (maxX - minX).clamp(1.0, double.infinity);
  final contentHeight = (maxY - minY).clamp(1.0, double.infinity);
  final outputWidth = (contentWidth + margin * 2).ceil();
  final outputHeight = (contentHeight + margin * 2).ceil();
  final desiredStroke = 2.4;
  final scaleFactor = targetHeight != null && targetHeight > 0 ? outputHeight / targetHeight : 1.0;
  final strokeWidth = (desiredStroke * scaleFactor).clamp(2.0, 12.0);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = const Color(0xFF1F2937)
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawColor(const Color(0x00000000), BlendMode.src);
  canvas.translate(-minX + margin, -minY + margin);

  for (final stroke in strokes) {
    if (stroke.length < 2) {
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(outputWidth, outputHeight);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  if (byteData == null) {
    return Uint8List(0);
  }
  return byteData.buffer.asUint8List();
}
