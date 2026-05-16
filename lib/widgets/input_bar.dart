import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/annotation_stroke.dart';
import '../screens/image_annotation_screen.dart';
import '../utils/time_utils.dart';

class InputBar extends StatefulWidget {
  final Function(String content, String? imagePath, DateTime? customTime)
  onSend;
  final bool enabled;
  final Color? notebookColor;

  const InputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.notebookColor,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  String? _attachedImagePath;
  String? _annotationBaseImagePath;
  List<AnnotationStroke>? _annotationStrokes;
  bool _isSending = false;
  DateTime? _selectedTime;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    setState(() {
                      _attachedImagePath = image.path;
                      _annotationBaseImagePath = null;
                      _annotationStrokes = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    setState(() {
                      _attachedImagePath = image.path;
                      _annotationBaseImagePath = null;
                      _annotationStrokes = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.draw_outlined,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: const Text('Blank Drawing'),
                onTap: () async {
                  Navigator.pop(context);
                  await _openAnnotationEditor();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAnnotationEditor({
    String? imagePath,
    List<AnnotationStroke> initialStrokes = const [],
  }) async {
    final result = await Navigator.of(context).push<ImageAnnotationResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageAnnotationScreen(
          imagePath: imagePath,
          initialStrokes: initialStrokes,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _attachedImagePath = result.imagePath;
      _annotationBaseImagePath = result.baseImagePath;
      _annotationStrokes = result.strokes;
    });
  }

  Future<void> _annotateAttachedImage() async {
    final imagePath = _attachedImagePath;
    if (imagePath == null) return;

    await _openAnnotationEditor(
      imagePath: _annotationStrokes == null
          ? imagePath
          : _annotationBaseImagePath,
      initialStrokes: _annotationStrokes ?? const [],
    );
  }

  void _removeImage() {
    setState(() {
      _attachedImagePath = null;
      _annotationBaseImagePath = null;
      _annotationStrokes = null;
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImagePath == null) return;

    setState(() => _isSending = true);

    try {
      await widget.onSend(text, _attachedImagePath, _selectedTime);
      _textController.clear();
      setState(() {
        _attachedImagePath = null;
        _annotationBaseImagePath = null;
        _annotationStrokes = null;
        _selectedTime = null;
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _showTimeOnlyPicker() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime != null
          ? TimeOfDay.fromDateTime(_selectedTime!)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final now = DateTime.now();
    setState(() {
      _selectedTime = DateTime(
        _selectedTime?.year ?? now.year,
        _selectedTime?.month ?? now.month,
        _selectedTime?.day ?? now.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    setState(() {
      final currentTime = _selectedTime ?? now;
      _selectedTime = DateTime(
        date.year,
        date.month,
        date.day,
        currentTime.hour,
        currentTime.minute,
      );
    });
  }

  void _clearSelectedTime() {
    setState(() => _selectedTime = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasContent =
        _textController.text.isNotEmpty || _attachedImagePath != null;

    const primary = Color(0xFF3b19e6);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom time indicator
            if (_selectedTime != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: primary),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _showTimeOnlyPicker,
                      child: Text(
                        TimeUtils.getEntryTime(_selectedTime!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(color: primary.withOpacity(0.5)),
                    ),
                    InkWell(
                      onTap: _showDatePicker,
                      child: Text(
                        TimeUtils.formatDate(_selectedTime!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearSelectedTime,
                      child: Icon(Icons.close, size: 14, color: primary),
                    ),
                  ],
                ),
              ),

            // Image preview
            if (_attachedImagePath != null)
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_attachedImagePath!),
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: GestureDetector(
                        onTap: _annotateAttachedImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.62),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.draw_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1B2E) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Camera button
                  IconButton(
                    onPressed: widget.enabled ? _pickImage : null,
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: isDark
                          ? const Color(0xFF9C93C8)
                          : Colors.grey[600],
                    ),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Time button
                  IconButton(
                    onPressed: widget.enabled ? _showTimeOnlyPicker : null,
                    icon: Icon(
                      _selectedTime != null
                          ? Icons.schedule
                          : Icons.schedule_outlined,
                      color: _selectedTime != null
                          ? primary
                          : (isDark
                                ? const Color(0xFF9C93C8)
                                : Colors.grey[600]),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Text input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2447).withOpacity(0.5)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        maxLines: 4,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your thoughts...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF9C93C8)
                                : Colors.grey[500],
                          ),
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),

                  // Send button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasContent
                          ? primary
                          : (isDark
                                ? const Color(0xFF2A2447)
                                : Colors.grey[200]),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: hasContent && widget.enabled && !_isSending
                            ? _send
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward,
                                  size: 20,
                                  color: hasContent
                                      ? Colors.white
                                      : (isDark
                                            ? const Color(0xFF9C93C8)
                                            : Colors.grey[500]),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
