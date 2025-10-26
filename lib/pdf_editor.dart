import 'dart:typed_data';
import 'dart:ui';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFormData {
  PdfFormData({
    required this.applicantName,
    required this.applicantEmail,
    required this.applicantPhone,
    required this.projectDescription,
    required this.effectiveDate,
    required this.requireOnsiteSupport,
    required this.enableDataSharing,
    required this.additionalNotes,
    required this.signatureStrokes,
    required this.signatureCanvasSize,
  });

  final String applicantName;
  final String applicantEmail;
  final String applicantPhone;
  final String projectDescription;
  final DateTime effectiveDate;
  final bool requireOnsiteSupport;
  final bool enableDataSharing;
  final String additionalNotes;
  final List<List<Offset>> signatureStrokes;
  final Size signatureCanvasSize;
}

Future<Uint8List> buildFilledPdf(PdfFormData data) async {
  final doc = pw.Document();
  final signatureImage = await _renderSignatureAsPng(data.signatureStrokes, data.signatureCanvasSize);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            pw.SizedBox(height: 16),
            _buildClientSummary(data),
            pw.SizedBox(height: 18),
            _buildProjectDetails(data),
            pw.SizedBox(height: 18),
            _buildEngagementOptions(data),
            pw.SizedBox(height: 22),
            _buildSignatureBlock(data, signatureImage),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _buildHeader() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Managed PDF Intake Packet', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(
        'Provide the required onboarding information to prepare the editable PDF deliverable.',
        style: const pw.TextStyle(fontSize: 11.5, color: PdfColors.grey700),
      ),
    ],
  );
}

pw.Widget _buildClientSummary(PdfFormData data) {
  return pw.Container(
    decoration: _sectionDecoration(),
    padding: const pw.EdgeInsets.all(16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Client Summary'),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _labeledField('Contact Name', data.applicantName)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _labeledField('Email', data.applicantEmail)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _labeledField('Phone', data.applicantPhone)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _labeledField('Effective Date', _formatDate(data.effectiveDate))),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildProjectDetails(PdfFormData data) {
  return pw.Container(
    decoration: _sectionDecoration(),
    padding: const pw.EdgeInsets.all(16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Project Details'),
        pw.SizedBox(height: 10),
        _labeledField('Scope Overview', data.projectDescription),
        if (data.additionalNotes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _labeledField('Notes', data.additionalNotes),
        ],
      ],
    ),
  );
}

pw.Widget _buildEngagementOptions(PdfFormData data) {
  return pw.Container(
    decoration: _sectionDecoration(),
    padding: const pw.EdgeInsets.all(16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Engagement Options'),
        pw.SizedBox(height: 12),
        _checkboxRow('On-site implementation support is required.', data.requireOnsiteSupport),
        pw.SizedBox(height: 8),
        _checkboxRow('Work-in-progress PDFs can be shared across teams.', data.enableDataSharing),
      ],
    ),
  );
}

pw.Widget _buildSignatureBlock(PdfFormData data, Uint8List signatureImage) {
  const double boxWidth = 360;
  const double boxHeight = 120;
  final hasSignature = signatureImage.isNotEmpty;

  return pw.Container(
    decoration: _sectionDecoration(),
    padding: const pw.EdgeInsets.all(16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Approval'),
        pw.SizedBox(height: 12),
        pw.Container(
          width: boxWidth,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.grey500, width: 1.2),
            color: PdfColor.fromInt(0xFFF7F7F7),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: boxHeight,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                ),
                child: hasSignature
                    ? pw.Image(pw.MemoryImage(signatureImage), fit: pw.BoxFit.contain)
                    : pw.Center(
                        child: pw.Text(
                          'No signature captured',
                          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
                        ),
                      ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Signed by: ${data.applicantName}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Date: ${_formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _labeledField(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 4),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.white,
        ),
        child: pw.Text(value, style: const pw.TextStyle(fontSize: 12.5, color: PdfColors.black)),
      ),
    ],
  );
}

pw.Widget _checkboxRow(String text, bool value) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _checkbox(value),
      pw.SizedBox(width: 8),
      pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 11.5))),
    ],
  );
}

pw.Widget _checkbox(bool checked) {
  return pw.Container(
    width: 14,
    height: 14,
    decoration: pw.BoxDecoration(
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      border: pw.Border.all(color: PdfColors.grey800, width: 1.2),
      color: checked ? PdfColors.indigo : PdfColors.white,
    ),
    child: checked
        ? pw.Center(
            child: pw.Container(
              width: 6,
              height: 6,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
          )
        : null,
  );
}

pw.BoxDecoration _sectionDecoration() {
  return pw.BoxDecoration(
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
    border: pw.Border.all(color: PdfColors.grey400, width: 1),
    color: PdfColor.fromInt(0xFFFDFDFD),
  );
}

pw.Widget _sectionTitle(String title) {
  return pw.Text(
    title,
    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
  );
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day/${value.year}';
}

Future<Uint8List> _renderSignatureAsPng(List<List<Offset>> strokes, Size canvasSize) async {
  if (strokes.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
    return Uint8List(0);
  }

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = const Color(0xFF1F2937)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawColor(const Color(0x00000000), BlendMode.src);

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

  final width = canvasSize.width.ceil();
  final height = canvasSize.height.ceil();
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  if (byteData == null) {
    return Uint8List(0);
  }
  return byteData.buffer.asUint8List();
}
