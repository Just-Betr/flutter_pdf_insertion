import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Simple signature capture widget that keeps stroke data in memory.
class SignaturePad extends HookWidget {
  const SignaturePad({
    super.key,
    required this.onChanged,
    required this.resetSignal,
    required this.canvasSize,
    this.strokeWidth = 2.4,
  });

  final ValueChanged<List<List<Offset>>> onChanged;
  final int resetSignal;
  final Size canvasSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final strokes = useState<List<List<Offset>>>(<List<Offset>>[]);
    final activeStroke = useState<List<Offset>>(<Offset>[]);

    void notifyParent() => onChanged(strokes.value);

    useEffect(() {
      strokes.value = <List<Offset>>[];
      activeStroke.value = <Offset>[];
      notifyParent();
      return null;
    }, [resetSignal]);

    void pushPoint(Offset position) {
      if (strokes.value.isEmpty) {
        return;
      }
      final updatedActive = <Offset>[...activeStroke.value, position];
      activeStroke.value = updatedActive;
      final updatedStrokes = <List<Offset>>[...strokes.value];
      updatedStrokes[updatedStrokes.length - 1] = updatedActive;
      strokes.value = updatedStrokes;
      notifyParent();
    }

    void finishStroke() {
      if (activeStroke.value.isEmpty) {
        return;
      }
      activeStroke.value = <Offset>[];
      notifyParent();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              final newStroke = <Offset>[details.localPosition];
              activeStroke.value = newStroke;
              strokes.value = <List<Offset>>[...strokes.value, newStroke];
              notifyParent();
            },
            onPanUpdate: (details) => pushPoint(details.localPosition),
            onPanEnd: (_) => finishStroke(),
            child: CustomPaint(
              painter: _SignaturePainter(strokes.value, strokeWidth, Theme.of(context).colorScheme.primary),
              willChange: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.strokeWidth, this.color);

  final List<List<Offset>> strokes;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

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
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    if (oldDelegate.strokes.length != strokes.length) {
      return true;
    }
    for (var i = 0; i < strokes.length; i++) {
      if (oldDelegate.strokes[i].length != strokes[i].length) {
        return true;
      }
    }
    return false;
  }
}
