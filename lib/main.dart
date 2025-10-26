import 'package:flutter/material.dart';
import 'controllers/pdf_form_controller.dart';
import 'services/pdf_service.dart';
import 'views/pdf_form_page.dart';

void main() {
  runApp(PdfEditApp());
}

class PdfEditApp extends StatelessWidget {
  PdfEditApp({super.key})
    : _controller = DefaultPdfFormController(pdfService: PdfGenerationServiceFactory.createDefault());

  final PdfFormController _controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Edit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: PdfFormPage(controller: _controller),
    );
  }
}
