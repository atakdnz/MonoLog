import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
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
                    setState(() => _attachedImagePath = image.path);
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
                    setState(() => _attachedImagePath = image.path);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() => _attachedImagePath = null);
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
    final hasContent =
        _textController.text.isNotEmpty || _attachedImagePath != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom time indicator
            if (_selectedTime != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: widget.notebookColor ?? theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showTimeOnlyPicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          TimeUtils.getEntryTime(_selectedTime!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                widget.notebookColor ??
                                theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '•',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _showDatePicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          TimeUtils.formatDate(_selectedTime!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                widget.notebookColor ??
                                theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearSelectedTime,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

            // Image preview
            if (_attachedImagePath != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                            color: Colors.black.withAlpha(153),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Camera button
                  IconButton(
                    onPressed: widget.enabled ? _pickImage : null,
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Time button
                  IconButton(
                    onPressed: widget.enabled ? _showTimeOnlyPicker : null,
                    icon: Icon(
                      _selectedTime != null
                          ? Icons.schedule
                          : Icons.schedule_outlined,
                      color: _selectedTime != null
                          ? (widget.notebookColor ?? theme.colorScheme.primary)
                          : theme.colorScheme.onSurface.withAlpha(153),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _selectedTime != null
                          ? (widget.notebookColor ?? theme.colorScheme.primary)
                                .withAlpha(30)
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: inputBarMinHeight,
                        maxHeight: inputBarMinHeight * inputBarMaxLines,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(102),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  IconButton(
                    onPressed: hasContent && widget.enabled && !_isSending
                        ? _send
                        : null,
                    icon: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: hasContent
                          ? (widget.notebookColor ?? theme.colorScheme.primary)
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: hasContent
                          ? Colors.white
                          : theme.colorScheme.onSurface.withAlpha(102),
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
