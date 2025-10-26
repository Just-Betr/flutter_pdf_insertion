import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../controllers/pdf_form_controller.dart';
import '../models/pdf_form_data.dart';
import 'widgets/signature_pad.dart';

class PdfFormPage extends HookWidget {
  const PdfFormPage({super.key, required this.controller});

  final PdfFormController controller;

  // Note there are a few helper functions in build.
  // Its to keep state management via hooks close to the UI code.
  // Additionally, these helpers rely on context which is only
  // available inside build. Instead of passing context around, we keep
  // them here.
  @override
  Widget build(final BuildContext context) {
    final firstNameController = useTextEditingController();
    final lastNameController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isGenerating = useState<bool>(false);
    final isPreviewing = useState<bool>(false);
    final isKewl = useState<bool>(false);
    final signatureController = useMemoized(() => SignaturePadController(), const []);
    useEffect(() {
      return signatureController.dispose;
    }, [signatureController]);

    double signatureHeight() {
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final targetHeight = viewportHeight * 0.25;
      // Give it some clamping to keep it usable on small screens.
      if (targetHeight < 160.0) {
        return 160.0;
      }
      if (targetHeight > 320.0) {
        return 320.0;
      }
      return targetHeight;
    }

    // If no signature size is set, provide a reasonable default.
    Size defaultSignatureSize() {
      final viewportWidth = MediaQuery.sizeOf(context).width;
      const horizontalPadding = 40.0;
      final width = viewportWidth > horizontalPadding ? viewportWidth - horizontalPadding : viewportWidth;
      return Size(width, signatureHeight());
    }

    bool hasSignature() => signatureController.hasSignature;

    // Really only used for generation/sharing and previewing.
    PdfFormData? prepareFormData() {
      FocusScope.of(context).unfocus();
      final messenger = ScaffoldMessenger.of(context);
      final currentState = formKey.currentState;
      if (currentState == null || !currentState.validate()) {
        messenger.showSnackBar(const SnackBar(content: Text('Please provide both names.')));
        return null;
      }
      if (!hasSignature()) {
        messenger.showSnackBar(const SnackBar(content: Text('Please add a signature.')));
        return null;
      }

      final strokesSnapshot = signatureController.strokes;
      final canvasSnapshot = signatureController.canvasSize == Size.zero
          ? defaultSignatureSize()
          : signatureController.canvasSize;

      return PdfFormData(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        isKewl: isKewl.value,
        signatureStrokes: strokesSnapshot,
        signatureCanvasSize: canvasSnapshot,
      );
    }

    Future<void> handleGenerate() async {
      final messenger = ScaffoldMessenger.of(context);
      if (isGenerating.value || isPreviewing.value) {
        return;
      }

      final data = prepareFormData();
      if (data == null) {
        return;
      }

      isGenerating.value = true;
      try {
        await controller.sharePdf(data);
        messenger.showSnackBar(const SnackBar(content: Text('PDF generated and ready to share.')));
      } catch (error) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to generate PDF: $error')));
      } finally {
        isGenerating.value = false;
      }
    }

    Future<void> handlePreview() async {
      final messenger = ScaffoldMessenger.of(context);
      if (isPreviewing.value || isGenerating.value) {
        return;
      }

      final data = prepareFormData();
      if (data == null) {
        return;
      }

      isPreviewing.value = true;
      try {
        await controller.previewPdf(data);
      } catch (error) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to preview PDF: $error')));
      } finally {
        isPreviewing.value = false;
      }
    }

    final isBusy = isGenerating.value || isPreviewing.value;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardInset = viewInsets.bottom;

    const double bottomControlsHeight = 160.0;

    return Scaffold(
      appBar: AppBar(title: const Text('PDF Form Insertion POC'), centerTitle: true),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: isBusy,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomControlsHeight + keyboardInset),
                  children: [
                    Text('Participant Details', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      textInputAction: TextInputAction.next,
                      validator: (final value) =>
                          value != null && value.trim().isNotEmpty ? null : 'Enter a first name',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      textInputAction: TextInputAction.done,
                      validator: (final value) => value != null && value.trim().isNotEmpty ? null : 'Enter a last name',
                    ),
                    CheckboxListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Are you Kewl?'),
                      value: isKewl.value,
                      onChanged: (final value) {
                        if (value != null) {
                          isKewl.value = value;
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Signature', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (final context, final constraints) {
                        final padWidth = constraints.maxWidth;
                        final padHeight = signatureHeight();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SignaturePad(controller: signatureController, canvasSize: Size(padWidth, padHeight)),
                            const SizedBox(height: 8),
                            AnimatedBuilder(
                              animation: signatureController,
                              builder: (final context, final _) => SizedBox(
                                width: padWidth,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Clear signature'),
                                  onPressed: signatureController.hasSignature ? signatureController.clear : null,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          if (isBusy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72)),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AbsorbPointer(
        absorbing: isBusy,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset > 0 ? keyboardInset : 0),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    icon: isGenerating.value
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(isGenerating.value ? 'Generating…' : 'Share PDF'),
                    onPressed: (isGenerating.value || isPreviewing.value) ? null : handleGenerate,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: isPreviewing.value
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.visibility_outlined),
                    label: Text(isPreviewing.value ? 'Opening preview…' : 'Preview PDF'),
                    onPressed: (isPreviewing.value || isGenerating.value) ? null : handlePreview,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
