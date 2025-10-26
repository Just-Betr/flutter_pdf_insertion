import 'dart:ui';

class PdfFormData {
  PdfFormData({
    required this.firstName,
    required this.lastName,
    required this.isKewl,
    required this.signatureStrokes,
    required this.signatureCanvasSize,
    final Map<String, dynamic>? additionalValues,
  }) : additionalValues = Map.unmodifiable(additionalValues ?? const {});

  final String firstName;
  final String lastName;
  final bool isKewl;
  final List<List<Offset>> signatureStrokes;
  final Size signatureCanvasSize;
  final Map<String, dynamic> additionalValues;
}
