import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SignaturePadController extends ChangeNotifier {
  SignaturePadController();

  List<List<Offset>> _strokes = const <List<Offset>>[];
  Size _canvasSize = Size.zero;
  VoidCallback? _clearCallback;

  List<List<Offset>> get strokes => _strokes.map((final stroke) => List<Offset>.from(stroke)).toList(growable: false);

  Size get canvasSize => _canvasSize;

  bool get hasSignature => _strokes.any((final stroke) => stroke.length > 1);

  bool get isEmpty => !hasSignature;

  void clear() {
    _clearCallback?.call();
  }

  void _bind({
    required final VoidCallback clearCallback,
    required final List<List<Offset>> initialStrokes,
    required final Size canvasSize,
  }) {
    _clearCallback = clearCallback;
    _updateFromWidget(initialStrokes, canvasSize);
  }

  void _unbind(final VoidCallback clearCallback) {
    if (identical(_clearCallback, clearCallback)) {
      _clearCallback = null;
    }
  }

  void _updateFromWidget(final List<List<Offset>> strokes, final Size canvasSize) {
    final hasSameSize = _canvasSize == canvasSize;
    final hasSameStrokes = _hasSameStrokes(strokes);
    if (hasSameSize && hasSameStrokes) {
      return;
    }
    _strokes = strokes.map((final stroke) => List<Offset>.unmodifiable(stroke)).toList(growable: false);
    _canvasSize = canvasSize;
    notifyListeners();
  }

  bool _hasSameStrokes(final List<List<Offset>> candidate) {
    if (_strokes.length != candidate.length) {
      return false;
    }
    for (var i = 0; i < candidate.length; i++) {
      if (!listEquals(_strokes[i], candidate[i])) {
        return false;
      }
    }
    return true;
  }
}

/// Signature capture widget that manages its own stroke state and exposes it via [SignaturePadController].
class SignaturePad extends HookWidget {
  const SignaturePad({super.key, required this.controller, required this.canvasSize, this.strokeWidth = 2.4});

  final SignaturePadController controller;
  final Size canvasSize;
  final double strokeWidth;

  @override
  Widget build(final BuildContext context) {
    final strokes = useMemoized(() => ValueNotifier<List<List<Offset>>>(<List<Offset>>[]), const []);
    final currentStroke = useRef<List<Offset>>(<Offset>[]);
    final isMounted = useRef<bool>(true);
    final scrollHold = useRef<ScrollHoldController?>(null);

    useEffect(() {
      isMounted.value = true;
      return () {
        scrollHold.value?.cancel();
        scrollHold.value = null;
        isMounted.value = false;
        strokes.dispose();
      };
    }, [strokes]);

    List<List<Offset>> snapshotStrokes() =>
        strokes.value.map((final stroke) => List<Offset>.from(stroke)).toList(growable: false);

    // Defer controller notifications so we never mutate parent state mid-build.
    void scheduleControllerSync() {
      WidgetsBinding.instance.addPostFrameCallback((final _) {
        if (!isMounted.value) {
          return;
        }
        controller._updateFromWidget(snapshotStrokes(), canvasSize);
      });
    }

    void clearPad() {
      currentStroke.value = <Offset>[];
      strokes.value = <List<Offset>>[];
      scheduleControllerSync();
    }

    useEffect(() {
      controller._bind(clearCallback: clearPad, initialStrokes: snapshotStrokes(), canvasSize: canvasSize);
      return () {
        controller._unbind(clearPad);
      };
    }, [controller, strokes, canvasSize]);

    // Pause the surrounding Scrollable while the user is drawing so drag gestures stay with the pad.
    void holdScrollIfNeeded() {
      if (scrollHold.value != null) {
        return;
      }
      final position = Scrollable.maybeOf(context)?.position;
      if (position != null) {
        scrollHold.value = position.hold(() {});
      }
    }

    // Resume normal scrolling once the stroke is complete or cancelled.
    void releaseScrollHold() {
      scrollHold.value?.cancel();
      scrollHold.value = null;
    }

    void startStroke(final Offset position) {
      final newStroke = <Offset>[position];
      currentStroke.value = newStroke;
      strokes.value = <List<Offset>>[...strokes.value, newStroke];
      scheduleControllerSync();
    }

    void handlePanDown(final DragDownDetails details) {
      holdScrollIfNeeded();
      if (currentStroke.value.isNotEmpty) {
        return;
      }
      startStroke(details.localPosition);
    }

    void pushPoint(final Offset position) {
      final active = currentStroke.value;
      if (active.isEmpty) {
        return;
      }
      active.add(position);
      strokes.value = List<List<Offset>>.from(strokes.value);
      scheduleControllerSync();
    }

    void finishStroke() {
      if (currentStroke.value.isEmpty) {
        releaseScrollHold();
        return;
      }
      currentStroke.value = <Offset>[];
      scheduleControllerSync();
      releaseScrollHold();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: RepaintBoundary(
        child: SizedBox(
          width: canvasSize.width,
          height: canvasSize.height,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            // RawGestureDetector lets us plug in a custom recogniser that wins the arena immediately.
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _ImmediatePanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_ImmediatePanGestureRecognizer>(
                  () => _ImmediatePanGestureRecognizer(),
                  (final instance) {
                    instance.onDown = handlePanDown;
                    instance.onStart = (final details) {
                      if (currentStroke.value.isEmpty) {
                        startStroke(details.localPosition);
                      }
                    };
                    instance.onUpdate = (final details) => pushPoint(details.localPosition);
                    instance.onEnd = (final _) => finishStroke();
                    instance.onCancel = finishStroke;
                  },
                ),
              },
              child: CustomPaint(
                painter: _SignaturePainter(strokes, strokeWidth, Theme.of(context).colorScheme.primary),
                isComplex: true,
                willChange: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.strokeWidth, this.color) : super(repaint: strokes);

  final ValueListenable<List<List<Offset>>> strokes;
  final double strokeWidth;
  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final stroke in strokes.value) {
      if (stroke.isEmpty) {
        continue;
      }
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, strokeWidth * 0.5, dotPaint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(final _SignaturePainter oldDelegate) {
    if (oldDelegate.strokeWidth != strokeWidth) {
      return true;
    }
    if (oldDelegate.color != color) {
      return true;
    }
    return false;
  }
}

class _ImmediatePanGestureRecognizer extends PanGestureRecognizer {
  _ImmediatePanGestureRecognizer() {
    dragStartBehavior = DragStartBehavior.down;
  }

  @override
  void addAllowedPointer(final PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Force-accept the pointer so vertical-first strokes are treated as drawing, not scrolling.
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
