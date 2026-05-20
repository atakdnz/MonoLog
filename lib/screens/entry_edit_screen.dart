import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import '../models/annotation_stroke.dart';
import '../models/entry.dart';
import '../providers/entries_provider.dart';
import '../providers/notebooks_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/image_annotation_screen.dart';
import '../services/annotation_metadata_service.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class EntryEditScreen extends StatefulWidget {
  final Entry entry;
  final String notebookId;

  const EntryEditScreen({
    super.key,
    required this.entry,
    required this.notebookId,
  });

  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen> {
  late TextEditingController _contentController;
  late DateTime _displayTime;
  late bool _isStarred;
  String? _imagePath;
  String? _annotationBaseImagePath;
  String? _annotationStrokes;
  bool _hasChanges = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.entry.content ?? '',
    );
    _displayTime = widget.entry.displayTime;
    _isStarred = widget.entry.isStarred;
    _imagePath = widget.entry.imagePath;
    _annotationBaseImagePath = widget.entry.annotationBaseImagePath;
    _annotationStrokes = widget.entry.annotationStrokes;

    _contentController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onChanged);
    _contentController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<_SavedImage?> _saveImage(
    String sourcePath, {
    String? annotationBaseImagePath,
    String? annotationStrokes,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(sourcePath).copy(destPath);

      var savedBaseImagePath = annotationBaseImagePath;
      var savedStrokes = annotationStrokes;

      final metadata = await AnnotationMetadataService.readMetadata(sourcePath);
      if (metadata != null && savedStrokes == null) {
        savedBaseImagePath = metadata.baseImagePath;
        savedStrokes = AnnotationMetadataService.encodeStrokes(
          metadata.strokes,
        );
      }

      if (savedStrokes != null) {
        String? baseImagePath = savedBaseImagePath;
        if (baseImagePath != null && await File(baseImagePath).exists()) {
          // Only copy the base image if it's not already in app storage.
          if (!p.isWithin(imagesDir.path, baseImagePath)) {
            final baseFileName =
                '${DateTime.now().millisecondsSinceEpoch}_base_${p.basename(baseImagePath)}';
            final baseDestPath = p.join(imagesDir.path, baseFileName);
            await File(baseImagePath).copy(baseDestPath);
            baseImagePath = baseDestPath;
          }
        }

        await AnnotationMetadataService.writeMetadata(
          imagePath: destPath,
          baseImagePath: baseImagePath,
          strokes: AnnotationMetadataService.decodeStrokes(savedStrokes),
        );
        savedBaseImagePath = baseImagePath;
      }

      return _SavedImage(
        imagePath: destPath,
        annotationBaseImagePath: savedBaseImagePath,
        annotationStrokes: savedStrokes,
      );
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
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
                    final savedImage = await _saveImage(image.path);
                    if (savedImage != null) {
                      setState(() {
                        _imagePath = savedImage.imagePath;
                        _annotationBaseImagePath = null;
                        _annotationStrokes = null;
                        _hasChanges = true;
                      });
                    }
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
                    final savedImage = await _saveImage(image.path);
                    if (savedImage != null) {
                      setState(() {
                        _imagePath = savedImage.imagePath;
                        _annotationBaseImagePath = null;
                        _annotationStrokes = null;
                        _hasChanges = true;
                      });
                    }
                  }
                },
              ),
              if (_imagePath != null) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  title: const Text('Remove Image'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imagePath = null;
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _annotateImage() async {
    final imagePath = _imagePath;
    if (imagePath == null) return;

    final metadata = await AnnotationMetadataService.readMetadata(imagePath);
    final baseImagePath =
        _annotationBaseImagePath ?? metadata?.baseImagePath ?? imagePath;
    final initialStrokes = _annotationStrokes != null
        ? AnnotationMetadataService.decodeStrokes(_annotationStrokes)
        : metadata?.strokes ?? const <AnnotationStroke>[];

    if (!mounted) return;
    final result = await Navigator.of(context).push<ImageAnnotationResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageAnnotationScreen(
          imagePath: baseImagePath,
          initialStrokes: initialStrokes,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final savedImage = await _saveImage(
      result.imagePath,
      annotationBaseImagePath: result.baseImagePath,
      annotationStrokes: AnnotationMetadataService.encodeStrokes(
        result.strokes,
      ),
    );
    if (savedImage == null || !mounted) return;

    setState(() {
      _imagePath = savedImage.imagePath;
      _annotationBaseImagePath = savedImage.annotationBaseImagePath;
      _annotationStrokes = savedImage.annotationStrokes;
      _hasChanges = true;
    });
  }

  Future<void> _pickTimeOnly() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_displayTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _displayTime = DateTime(
        _displayTime.year,
        _displayTime.month,
        _displayTime.day,
        time.hour,
        time.minute,
      );
      _hasChanges = true;
    });
  }

  Future<void> _pickDateOnly() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _displayTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    setState(() {
      _displayTime = DateTime(
        date.year,
        date.month,
        date.day,
        _displayTime.hour,
        _displayTime.minute,
      );
      _hasChanges = true;
    });
  }

  void _toggleStar() {
    setState(() {
      _isStarred = !_isStarred;
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();

    if (content.isEmpty && _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry must have content or an image')),
      );
      return;
    }

    final updatedEntry = widget.entry.copyWith(
      content: content.isEmpty ? null : content,
      imagePath: _imagePath,
      annotationBaseImagePath: _annotationBaseImagePath,
      annotationStrokes: _annotationStrokes,
      displayTime: _displayTime,
      isStarred: _isStarred,
      updatedAt: DateTime.now(),
      clearContent: content.isEmpty,
      clearImagePath: _imagePath == null && widget.entry.imagePath != null,
      clearAnnotationBaseImagePath: _annotationBaseImagePath == null,
      clearAnnotationStrokes: _annotationStrokes == null,
    );

    await context.read<EntriesProvider>().updateEntry(updatedEntry);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showMoveDialog() async {
    final provider = context.read<NotebooksProvider>();
    await provider.loadNotebooks();

    final allNotebooks = [
      ...provider.pinnedNotebooks,
      ...provider.regularNotebooks,
    ].where((n) => n.id != widget.notebookId).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Move to...',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (allNotebooks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No other notebooks available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              )
            else
              ...allNotebooks.map(
                (notebook) => ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: NotebookColors.fromHex(notebook.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(notebook.title),
                  onTap: () async {
                    Navigator.pop(context);
                    await context.read<EntriesProvider>().moveEntry(
                      widget.entry.id,
                      notebook.id,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Moved to ${notebook.title}')),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This entry will be moved to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<EntriesProvider>().deleteEntry(
                widget.entry.id,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entry moved to trash')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Entry'),
          actions: [
            IconButton(
              icon: Icon(
                _isStarred ? Icons.star : Icons.star_outline,
                color: _isStarred ? Colors.amber[600] : null,
              ),
              onPressed: _toggleStar,
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _hasChanges ? _save : null,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time and Date selectors (separate)
              Row(
                children: [
                  // Time selector
                  Expanded(
                    child: InkWell(
                      onTap: _pickTimeOnly,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withAlpha(153),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TimeUtils.getEntryTime(_displayTime),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date selector
                  Expanded(
                    child: InkWell(
                      onTap: _pickDateOnly,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withAlpha(153),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TimeUtils.formatDate(_displayTime),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content text field
              TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16.0) * Provider.of<ThemeProvider>(context).fontSizeScaleFactor,
                ),
                decoration: InputDecoration(
                  hintText: 'Write your entry...',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image section
              if (_imagePath != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_imagePath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _buildImageButton(Icons.edit, _pickImage),
                          const SizedBox(width: 8),
                          _buildImageButton(
                            Icons.draw_outlined,
                            _annotateImage,
                          ),
                          const SizedBox(width: 8),
                          _buildImageButton(Icons.delete, () {
                            setState(() {
                              _imagePath = null;
                              _annotationBaseImagePath = null;
                              _annotationStrokes = null;
                              _hasChanges = true;
                            });
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Image'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showMoveDialog,
                      icon: const Icon(Icons.drive_file_move_outlined),
                      label: const Text('Move'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showDeleteConfirmation,
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _SavedImage {
  final String imagePath;
  final String? annotationBaseImagePath;
  final String? annotationStrokes;

  const _SavedImage({
    required this.imagePath,
    required this.annotationBaseImagePath,
    required this.annotationStrokes,
  });
}
