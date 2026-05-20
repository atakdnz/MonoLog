import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/annotation_stroke.dart';
import '../services/annotation_metadata_service.dart';

class ImageAnnotationScreen extends StatefulWidget {
  final String? imagePath;
  final List<AnnotationStroke> initialStrokes;

  const ImageAnnotationScreen({
    super.key,
    this.imagePath,
    this.initialStrokes = const [],
  });

  @override
  State<ImageAnnotationScreen> createState() => _ImageAnnotationScreenState();
}

class _ImageAnnotationScreenState extends State<ImageAnnotationScreen> {
  final _canvasKey = GlobalKey();
  final List<AnnotationStroke> _strokes = [];
  final List<AnnotationStroke> _redoStack = [];
  final List<Offset> _currentPoints = [];

  ui.Image? _backgroundImage;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEraser = false;
  bool _usesBrushEraser = false;
  Color _penColor = Colors.black;
  double _penWidth = 5;
  double _eraserWidth = 18;

  /// The current layout size of the canvas, updated by LayoutBuilder.
  Size _currentCanvasSize = Size.zero;

  static const _blankCanvasSize = Size(1080, 1080);
  static const _colors = [
    Colors.black,
    Colors.white,
    Color(0xFFE53935),
    Color(0xFFFFB300),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
  ];

  @override
  void initState() {
    super.initState();
    // initialStrokes are in normalized [0,1] coordinates; they will be
    // denormalized to screen pixels once the first layout is known.
    _strokes.addAll(widget.initialStrokes);
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    if (widget.imagePath == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final bytes = await File(widget.imagePath!).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _backgroundImage = frame.image;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Size get _sourceSize {
    final image = _backgroundImage;
    if (image == null) return _blankCanvasSize;
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  // --- Coordinate conversion helpers ---

  /// Convert a normalized [0,1] offset to layout-pixel coordinates.
  Offset _denormalize(Offset normalized, Size canvasSize) {
    return Offset(
      normalized.dx * canvasSize.width,
      normalized.dy * canvasSize.height,
    );
  }

  /// Convert a layout-pixel offset to normalized [0,1] coordinates.
  Offset _normalize(Offset pixel, Size canvasSize) {
    if (canvasSize.width == 0 || canvasSize.height == 0) return Offset.zero;
    return Offset(pixel.dx / canvasSize.width, pixel.dy / canvasSize.height);
  }

  /// Denormalize an entire stroke to layout pixels.
  AnnotationStroke _denormalizeStroke(
    AnnotationStroke stroke,
    Size canvasSize,
  ) {
    return AnnotationStroke(
      points: stroke.points.map((pt) => _denormalize(pt, canvasSize)).toList(),
      color: stroke.color,
      width: stroke.width * canvasSize.width,
    );
  }

  /// Normalize a stroke from layout pixels to [0,1].
  AnnotationStroke _normalizeStroke(AnnotationStroke stroke, Size canvasSize) {
    if (canvasSize.width == 0 || canvasSize.height == 0) return stroke;
    return AnnotationStroke(
      points: stroke.points.map((pt) => _normalize(pt, canvasSize)).toList(),
      color: stroke.color,
      width: stroke.width / canvasSize.width,
    );
  }

  /// Denormalize all strokes in the list.
  List<AnnotationStroke> _denormalizeAll(
    List<AnnotationStroke> strokes,
    Size canvasSize,
  ) {
    return strokes.map((s) => _denormalizeStroke(s, canvasSize)).toList();
  }

  /// Normalize all strokes in the list.
  List<AnnotationStroke> _normalizeAll(
    List<AnnotationStroke> strokes,
    Size canvasSize,
  ) {
    return strokes.map((s) => _normalizeStroke(s, canvasSize)).toList();
  }

  // --- Stroke interaction ---

  void _startStroke(Offset point) {
    if (_isEraser) {
      _eraseAt(point);
      return;
    }

    setState(() {
      _currentPoints
        ..clear()
        ..add(point);
      _redoStack.clear();
    });
  }

  void _extendStroke(Offset point) {
    if (_isEraser) {
      _eraseAt(point);
      return;
    }

    setState(() => _currentPoints.add(point));
  }

  void _finishStroke() {
    if (_isEraser || _currentPoints.isEmpty) return;

    setState(() {
      _strokes.add(
        AnnotationStroke(
          points: List.of(_currentPoints),
          color: _penColor,
          width: _penWidth,
        ),
      );
      _currentPoints.clear();
    });
  }

  void _eraseAt(Offset point) {
    if (_usesBrushEraser) {
      _brushEraseAt(point);
      return;
    }

    final index = _strokes.lastIndexWhere(
      (stroke) => stroke.hitTest(point, _eraserWidth),
    );
    if (index == -1) return;

    setState(() {
      _redoStack
        ..clear()
        ..add(_strokes.removeAt(index));
    });
  }

  void _brushEraseAt(Offset point) {
    var changed = false;
    final updatedStrokes = <AnnotationStroke>[];

    for (final stroke in _strokes) {
      final segments = stroke.eraseAt(point, _eraserWidth);
      if (segments.length != 1 ||
          segments.first.points.length != stroke.points.length) {
        changed = true;
      }
      updatedStrokes.addAll(segments);
    }

    if (!changed) return;

    setState(() {
      _redoStack.clear();
      _strokes
        ..clear()
        ..addAll(updatedStrokes);
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redoStack.add(_strokes.removeLast()));
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() => _strokes.add(_redoStack.removeLast()));
  }

  void _clearAnnotations() {
    if (_strokes.isEmpty && _currentPoints.isEmpty) return;
    setState(() {
      _redoStack
        ..clear()
        ..addAll(_strokes);
      _strokes.clear();
      _currentPoints.clear();
    });
  }

  Future<void> _saveAnnotatedImage() async {
    setState(() => _isSaving = true);

    try {
      final boundary =
          _canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final sourceName = widget.imagePath == null
          ? 'blank_canvas'
          : p.basenameWithoutExtension(widget.imagePath!);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${sourceName}_annotated.png';
      final outputPath = p.join(tempDir.path, fileName);
      await File(outputPath).writeAsBytes(byteData.buffer.asUint8List());

      // For blank canvas drawings, create a real white PNG so re-editing
      // works identically to photo annotations.
      String? baseImagePath = widget.imagePath;
      if (baseImagePath == null) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        final picture = recorder.endRecording();
        final blankImage = await picture.toImage(
          _blankCanvasSize.width.toInt(),
          _blankCanvasSize.height.toInt(),
        );
        final blankData = await blankImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (blankData != null) {
          final blankPath = p.join(
            tempDir.path,
            '${DateTime.now().millisecondsSinceEpoch}_blank_base.png',
          );
          await File(blankPath).writeAsBytes(blankData.buffer.asUint8List());
          baseImagePath = blankPath;
        }
      }

      // Normalize strokes to [0,1] before writing metadata / returning.
      final normalizedStrokes = _normalizeAll(_strokes, _currentCanvasSize);

      await AnnotationMetadataService.writeMetadata(
        imagePath: outputPath,
        baseImagePath: baseImagePath,
        strokes: normalizedStrokes,
      );

      if (!mounted) return;
      Navigator.pop(
        context,
        ImageAnnotationResult(
          imagePath: outputPath,
          baseImagePath: baseImagePath,
          strokes: List.unmodifiable(normalizedStrokes),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceSize = _sourceSize;
    final aspectRatio = sourceSize.width / sourceSize.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.imagePath == null ? 'Blank Drawing' : 'Annotate'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Clear annotations',
            onPressed: _strokes.isEmpty ? null : _clearAnnotations,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveAnnotatedImage,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: RepaintBoundary(
                              key: _canvasKey,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );

                                  // When the layout size changes (first build
                                  // or orientation change) convert the stored
                                  // normalized strokes to layout-pixel space.
                                  if (_currentCanvasSize != size) {
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      if (!mounted) return;
                                      final oldSize = _currentCanvasSize;
                                      _currentCanvasSize = size;

                                      // First layout — denormalize from [0,1].
                                      if (oldSize == Size.zero) {
                                        setState(() {
                                          final denormalized = _denormalizeAll(
                                            _strokes,
                                            size,
                                          );
                                          _strokes
                                            ..clear()
                                            ..addAll(denormalized);
                                        });
                                      } else {
                                        // Relayout — rescale from old size to
                                        // new size. Normalize then denormalize.
                                        setState(() {
                                          final normalized = _normalizeAll(
                                            _strokes,
                                            oldSize,
                                          );
                                          final denormalized = _denormalizeAll(
                                            normalized,
                                            size,
                                          );
                                          _strokes
                                            ..clear()
                                            ..addAll(denormalized);
                                        });
                                      }
                                    });
                                  }

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (details) =>
                                        _startStroke(details.localPosition),
                                    onPanUpdate: (details) =>
                                        _extendStroke(details.localPosition),
                                    onPanEnd: (_) => _finishStroke(),
                                    child: CustomPaint(
                                      size: size,
                                      painter: _AnnotationPainter(
                                        backgroundImage: _backgroundImage,
                                        strokes: List.of(_strokes),
                                        activeStroke: _isEraser
                                            ? null
                                            : AnnotationStroke(
                                                points: _currentPoints,
                                                color: _penColor,
                                                width: _penWidth,
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.edit_rounded),
                                  label: Text('Pen'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.cleaning_services_rounded),
                                  label: Text('Eraser'),
                                ),
                              ],
                              selected: {_isEraser},
                              onSelectionChanged: (selection) {
                                setState(() => _isEraser = selection.first);
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Slider(
                                value: _isEraser ? _eraserWidth : _penWidth,
                                min: _isEraser ? 8 : 2,
                                max: _isEraser ? 56 : 24,
                                divisions: _isEraser ? 12 : 11,
                                label:
                                    '${(_isEraser ? _eraserWidth : _penWidth).round()}',
                                onChanged: (value) {
                                  setState(() {
                                    if (_isEraser) {
                                      _eraserWidth = value;
                                    } else {
                                      _penWidth = value;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _isEraser
                            ? Row(
                                children: [
                                  Text(
                                    'Erase',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SegmentedButton<bool>(
                                        segments: const [
                                          ButtonSegment(
                                            value: false,
                                            icon: Icon(Icons.gesture_rounded),
                                            label: Text('Stroke'),
                                          ),
                                          ButtonSegment(
                                            value: true,
                                            icon: Icon(Icons.brush_rounded),
                                            label: Text('Brush'),
                                          ),
                                        ],
                                        selected: {_usesBrushEraser},
                                        onSelectionChanged: (selection) {
                                          setState(
                                            () => _usesBrushEraser =
                                                selection.first,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Text(
                                    'Color',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _colors.map((color) {
                                          final isSelected = color == _penColor;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: InkWell(
                                              onTap: () => setState(
                                                () => _penColor = color,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 140,
                                                ),
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : Colors.black.withValues(
                                                            alpha:
                                                                color ==
                                                                    Colors.white
                                                                ? 0.22
                                                                : 0.08,
                                                          ),
                                                    width: isSelected ? 3 : 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ImageAnnotationResult {
  final String imagePath;
  final String? baseImagePath;
  final List<AnnotationStroke> strokes;

  const ImageAnnotationResult({
    required this.imagePath,
    required this.baseImagePath,
    required this.strokes,
  });
}

class _AnnotationPainter extends CustomPainter {
  final ui.Image? backgroundImage;
  final List<AnnotationStroke> strokes;
  final AnnotationStroke? activeStroke;

  const _AnnotationPainter({
    required this.backgroundImage,
    required this.strokes,
    required this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);

    final image = backgroundImage;
    if (image != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }

    final active = activeStroke;
    if (active != null) {
      _paintStroke(canvas, active);
    }
  }

  void _paintStroke(Canvas canvas, AnnotationStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      final previous = stroke.points[i - 1];
      final current = stroke.points[i];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}
