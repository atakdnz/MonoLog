import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/annotation_stroke.dart';
import '../models/notebook.dart';
import '../models/entry.dart';
import '../providers/entries_provider.dart';
import '../providers/notebooks_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import '../widgets/entry_bubble.dart';
import '../widgets/date_header.dart';
import '../widgets/input_bar.dart';
import 'image_annotation_screen.dart';
import '../services/annotation_metadata_service.dart';
import 'entry_edit_screen.dart';
import 'notebook_details_screen.dart';

enum _ClassicInlineFormat { bold, italic, code }

enum _ClassicLineFormat { heading, bullet, quote }

class NotebookScreen extends StatefulWidget {
  final Notebook notebook;
  final String? initialEntryId;

  const NotebookScreen({
    super.key,
    required this.notebook,
    this.initialEntryId,
  });

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final _scrollController = ScrollController();
  final _classicController = _ClassicRichTextController();
  late Notebook _notebook;
  bool _isSearching = false;
  bool _showStarredOnly = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  int _chatSearchCurrentMatch = 0;
  List<String> _chatSearchMatchIds = [];
  int _classicSearchCurrentMatch = 0;
  List<TextRange> _classicSearchMatches = [];
  Timer? _classicSaveDebounce;
  String? _classicEntryId;
  bool _isApplyingClassicText = false;
  _ClassicEditorSnapshot _lastClassicSnapshot = _ClassicEditorSnapshot.empty();
  final List<_ClassicEditorSnapshot> _classicUndoStack = [];
  final List<_ClassicEditorSnapshot> _classicRedoStack = [];
  _ClassicEditorSnapshot? _classicTypingUndoBase;
  Timer? _classicHistoryDebounce;
  bool _showClassicFormattingBar = false;
  final Set<String> _selectedEntryIds = {};

  bool get _isSelectingEntries => _selectedEntryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    _lastClassicSnapshot = _classicController.snapshot();
    _classicController.addListener(_trackClassicHistory);
    _classicController.addListener(_scheduleClassicSave);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EntriesProvider>().setNotebook(_notebook.id).then((_) {
        if (_notebook.entryStyle == NotebookEntryStyles.classic && mounted) {
          _syncClassicEditor();
        }
        if (widget.initialEntryId != null && mounted) {
          _scrollToEntry(widget.initialEntryId!);
        }
      });
    });
  }

  @override
  void dispose() {
    _classicSaveDebounce?.cancel();
    _classicHistoryDebounce?.cancel();
    _scrollController.dispose();
    _classicController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _syncClassicEditor() {
    final entries = context.read<EntriesProvider>().entries;
    final entry = entries.isEmpty ? null : entries.first;
    final document = _ClassicMarkdownCodec.decode(entry?.content ?? '');
    _classicEntryId = entry?.id;
    _isApplyingClassicText = true;
    _classicController.restore(document);
    _classicController.selection = TextSelection.collapsed(
      offset: _classicController.text.length,
    );
    _lastClassicSnapshot = _classicController.snapshot();
    _classicUndoStack.clear();
    _classicRedoStack.clear();
    _classicTypingUndoBase = null;
    _isApplyingClassicText = false;
  }

  void _trackClassicHistory() {
    if (_isApplyingClassicText ||
        _notebook.entryStyle != NotebookEntryStyles.classic) {
      _lastClassicSnapshot = _classicController.snapshot();
      return;
    }

    final currentSnapshot = _classicController.snapshot();
    if (currentSnapshot.hasSameContent(_lastClassicSnapshot)) {
      _lastClassicSnapshot = currentSnapshot;
      return;
    }

    _classicTypingUndoBase ??= _lastClassicSnapshot;
    _classicHistoryDebounce?.cancel();
    _classicHistoryDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _classicTypingUndoBase == null) return;
      _pushClassicUndoSnapshot(_classicTypingUndoBase!);
      _classicTypingUndoBase = null;
      setState(() {});
    });
    _classicController.reflowInlineFormats(_lastClassicSnapshot.text);
    if (_isSearching && _notebook.entryStyle == NotebookEntryStyles.classic) {
      _updateClassicSearchMatches(_searchController.text);
    }
    _classicRedoStack.clear();
    _lastClassicSnapshot = _classicController.snapshot();
    if (mounted) setState(() {});
  }

  void _pushClassicUndoSnapshot(_ClassicEditorSnapshot snapshot) {
    if (_classicUndoStack.isNotEmpty &&
        _classicUndoStack.last.hasSameContent(snapshot)) {
      return;
    }
    _classicUndoStack.add(snapshot);
    if (_classicUndoStack.length > 100) {
      _classicUndoStack.removeAt(0);
    }
  }

  void _setClassicSnapshotFromHistory(_ClassicEditorSnapshot snapshot) {
    _isApplyingClassicText = true;
    _classicController.restore(snapshot);
    _lastClassicSnapshot = _classicController.snapshot();
    _classicTypingUndoBase = null;
    _classicHistoryDebounce?.cancel();
    _isApplyingClassicText = false;
    _scheduleClassicSave();
    if (mounted) setState(() {});
  }

  void _undoClassicEdit() {
    _flushClassicTypingUndoStep();
    if (_classicUndoStack.isEmpty) return;
    _classicRedoStack.add(_classicController.snapshot());
    _setClassicSnapshotFromHistory(_classicUndoStack.removeLast());
  }

  void _redoClassicEdit() {
    if (_classicRedoStack.isEmpty) return;
    _classicUndoStack.add(_classicController.snapshot());
    _setClassicSnapshotFromHistory(_classicRedoStack.removeLast());
  }

  void _flushClassicTypingUndoStep() {
    if (_classicTypingUndoBase == null) return;
    _classicHistoryDebounce?.cancel();
    _pushClassicUndoSnapshot(_classicTypingUndoBase!);
    _classicTypingUndoBase = null;
  }

  void _applyInlineClassicFormat(_ClassicInlineFormat format) {
    _flushClassicTypingUndoStep();
    final before = _classicController.snapshot();
    _classicController.toggleInlineFormat(format);
    if (!_classicController.snapshot().hasSameContent(before)) {
      _pushClassicUndoSnapshot(before);
      _classicRedoStack.clear();
      _scheduleClassicSave();
    }
    _classicRedoStack.clear();
    _lastClassicSnapshot = _classicController.snapshot();
    setState(() {});
  }

  void _applyLineClassicFormat(_ClassicLineFormat format) {
    _flushClassicTypingUndoStep();
    final before = _classicController.snapshot();
    _classicController.toggleLineFormat(format);
    if (!_classicController.snapshot().hasSameContent(before)) {
      _pushClassicUndoSnapshot(before);
      _classicRedoStack.clear();
      _scheduleClassicSave();
    }
    _lastClassicSnapshot = _classicController.snapshot();
    setState(() {});
  }

  void _scheduleClassicSave() {
    if (_isApplyingClassicText ||
        _notebook.entryStyle != NotebookEntryStyles.classic) {
      return;
    }

    _classicSaveDebounce?.cancel();
    _classicSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      _saveClassicNote();
    });
  }

  Future<void> _saveClassicNote() async {
    if (!mounted || _notebook.entryStyle != NotebookEntryStyles.classic) return;

    final provider = context.read<EntriesProvider>();
    final text = _ClassicMarkdownCodec.encode(_classicController.snapshot());

    if (_classicEntryId == null) {
      if (text.trim().isEmpty) return;
      final entry = await provider.addEntry(content: text);
      _classicEntryId = entry.id;
      return;
    }

    final entry = await provider.getEntry(_classicEntryId!);
    if (entry == null) {
      _classicEntryId = null;
      if (text.trim().isNotEmpty) {
        final newEntry = await provider.addEntry(content: text);
        _classicEntryId = newEntry.id;
      }
      return;
    }

    if (entry.content == text) return;
    await provider.updateEntry(entry.copyWith(content: text));
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

  Future<void> _handleSend(
    String content,
    String? imagePath,
    DateTime? customTime,
    String? annotationBaseImagePath,
    String? annotationStrokes,
  ) async {
    _SavedImage? savedImage;
    if (imagePath != null) {
      savedImage = await _saveImage(
        imagePath,
        annotationBaseImagePath: annotationBaseImagePath,
        annotationStrokes: annotationStrokes,
      );
    }

    await context.read<EntriesProvider>().addEntry(
      content: content,
      imagePath: savedImage?.imagePath,
      annotationBaseImagePath: savedImage?.annotationBaseImagePath,
      annotationStrokes: savedImage?.annotationStrokes,
      displayTime: customTime,
    );

    // Scroll to top (newest entries)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: normalAnimation,
        curve: Curves.easeOut,
      );
    }
  }

  List<Entry> _visibleChatEntries(EntriesProvider provider) {
    var entries = provider.entries;

    if (_showStarredOnly) {
      entries = entries.where((e) => e.isStarred).toList();
    }

    return entries;
  }

  void _toggleEntrySelection(Entry entry) {
    setState(() {
      if (_selectedEntryIds.contains(entry.id)) {
        _selectedEntryIds.remove(entry.id);
      } else {
        _selectedEntryIds.add(entry.id);
      }
    });
  }

  void _clearEntrySelection() {
    setState(_selectedEntryIds.clear);
  }

  void _selectVisibleEntries(List<Entry> entries) {
    setState(() {
      _selectedEntryIds
        ..clear()
        ..addAll(entries.map((entry) => entry.id));
    });
  }

  List<Entry> _selectedEntriesInReadingOrder(List<Entry> entries) {
    return entries
        .where((entry) => _selectedEntryIds.contains(entry.id))
        .toList()
        .reversed
        .toList();
  }

  String _copyTextForEntries(List<Entry> entries) {
    return entries
        .map((entry) {
          final parts = <String>[];
          if (entry.hasContent) {
            parts.add(entry.content!.trimRight());
          }
          if (entry.hasImage) {
            parts.add('[Image: ${entry.imagePath}]');
          }
          return parts.join('\n');
        })
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
  }

  Future<void> _copySelectedEntries(List<Entry> visibleEntries) async {
    final selectedEntries = _selectedEntriesInReadingOrder(visibleEntries);
    final text = _copyTextForEntries(selectedEntries);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected entries have nothing to copy')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedEntries.length == 1
              ? 'Entry copied'
              : '${selectedEntries.length} entries copied',
        ),
      ),
    );
    _clearEntrySelection();
  }

  Future<void> _setSelectedEntriesStarred(
    List<Entry> visibleEntries,
    bool isStarred,
  ) async {
    final selectedEntries = _selectedEntriesInReadingOrder(visibleEntries);
    if (selectedEntries.isEmpty) return;

    await context.read<EntriesProvider>().setEntriesStarred(
      selectedEntries.map((entry) => entry.id).toList(),
      isStarred,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedEntries.length == 1
              ? (isStarred ? 'Entry starred' : 'Star removed')
              : isStarred
              ? '${selectedEntries.length} entries starred'
              : 'Stars removed from ${selectedEntries.length} entries',
        ),
      ),
    );
    _clearEntrySelection();
  }

  void _showEntryOptions(Entry entry, {bool includePrimaryActions = true}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (includePrimaryActions)
                ListTile(
                  leading: Icon(
                    entry.isStarred ? Icons.star : Icons.star_outline,
                    color: entry.isStarred ? Colors.amber[600] : null,
                  ),
                  title: Text(entry.isStarred ? 'Remove Star' : 'Add Star'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearEntrySelection();
                    context.read<EntriesProvider>().toggleStar(entry.id);
                  },
                ),
              if (includePrimaryActions)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearEntrySelection();
                    _navigateToEdit(entry);
                  },
                ),
              if (includePrimaryActions && entry.hasImage)
                ListTile(
                  leading: const Icon(Icons.draw_outlined),
                  title: const Text('Edit Drawing'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearEntrySelection();
                    _annotateEntryImage(entry);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to...'),
                onTap: () {
                  Navigator.pop(context);
                  _clearEntrySelection();
                  _showMoveDialog(entry);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearEntrySelection();
                  context.read<EntriesProvider>().deleteEntry(entry.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry moved to trash')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEdit(Entry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditScreen(entry: entry, notebookId: _notebook.id),
      ),
    ).then((_) {
      context.read<EntriesProvider>().loadEntries();
    });
  }

  Future<void> _annotateEntryImage(Entry entry) async {
    if (!entry.hasImage) return;

    final metadata = await AnnotationMetadataService.readMetadata(
      entry.imagePath!,
    );
    final baseImagePath =
        entry.annotationBaseImagePath ??
        metadata?.baseImagePath ??
        entry.imagePath!;
    final initialStrokes = entry.annotationStrokes != null
        ? AnnotationMetadataService.decodeStrokes(entry.annotationStrokes)
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

    await context.read<EntriesProvider>().updateEntry(
      entry.copyWith(
        imagePath: savedImage.imagePath,
        annotationBaseImagePath: savedImage.annotationBaseImagePath,
        annotationStrokes: savedImage.annotationStrokes,
      ),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Drawing updated')));
  }

  void _showMoveDialog(Entry entry) async {
    await context.read<NotebooksProvider>().loadNotebooks();
    final provider = context.read<NotebooksProvider>();
    final allNotebooks = [
      ...provider.pinnedNotebooks,
      ...provider.regularNotebooks,
    ].where((n) => n.id != _notebook.id).toList();

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
                      entry.id,
                      notebook.id,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Moved to ${notebook.title}')),
                      );
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

  void _showJumpToDatePicker() async {
    final entries = context.read<EntriesProvider>().entries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to navigate to')),
      );
      return;
    }

    final oldestDate = entries.last.displayTime;
    final newestDate = entries.first.displayTime;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: newestDate,
      firstDate: oldestDate,
      lastDate: newestDate,
    );

    if (selectedDate == null || !mounted) return;

    // Entries are sorted newest-first. With a reversed list, the last matching
    // entry is the first one shown for that date.
    int targetIndex = entries.lastIndexWhere(
      (e) => TimeUtils.isSameDay(e.displayTime, selectedDate),
    );

    if (targetIndex == -1) {
      // Find nearest date
      int nearestIndex = 0;
      int minDiff = 999999;
      for (int i = 0; i < entries.length; i++) {
        final diff = entries[i].displayTime
            .difference(selectedDate)
            .inDays
            .abs();
        if (diff < minDiff) {
          minDiff = diff;
          nearestIndex = i;
        }
      }
      targetIndex = nearestIndex;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No entries on selected date. Jumping to ${TimeUtils.getShortDate(entries[targetIndex].displayTime)}',
          ),
        ),
      );
    }

    _scrollToEntry(entries[targetIndex].id);
  }

  void _scrollToEntry(String entryId, {bool clearSearch = true}) {
    final provider = context.read<EntriesProvider>();
    final index = provider.entries.indexWhere((e) => e.id == entryId);
    if (index < 0 || !_scrollController.hasClients) return;

    if (clearSearch) {
      setState(() {
        _isSearching = false;
        _searchController.clear();
        _clearSearchMatches();
      });
    }

    setState(() {
      _showStarredOnly = false;
    });

    // Reversed list with variable-height rows: start with a good estimate,
    // then let the user fine-tune naturally from the focused region.
    final estimatedOffset = index * 100.0;
    _scrollController.animateTo(
      estimatedOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: normalAnimation,
      curve: Curves.easeOut,
    );
  }

  void _toggleSearch() {
    final shouldEnableSearch = !_isSearching;
    setState(() {
      _selectedEntryIds.clear();
      _isSearching = shouldEnableSearch;
      if (!_isSearching) {
        _searchController.clear();
        _clearSearchMatches();
      } else if (_notebook.entryStyle == NotebookEntryStyles.classic) {
        _updateClassicSearchMatches(_searchController.text);
      } else {
        _updateChatSearchMatches(_searchController.text);
      }
    });
    if (shouldEnableSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  void _performSearch(String query) {
    if (_notebook.entryStyle == NotebookEntryStyles.classic) {
      setState(() => _updateClassicSearchMatches(query));
      return;
    }

    setState(() => _updateChatSearchMatches(query));
  }

  void _clearSearchMatches() {
    _clearChatSearchMatches();
    _clearClassicSearchMatches();
  }

  void _clearChatSearchMatches() {
    _chatSearchMatchIds = [];
    _chatSearchCurrentMatch = 0;
  }

  void _updateChatSearchMatches(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _clearChatSearchMatches();
      return;
    }

    final lowerQuery = trimmedQuery.toLowerCase();
    _chatSearchMatchIds = context
        .read<EntriesProvider>()
        .entries
        .where(
          (entry) =>
              entry.hasContent &&
              entry.content!.toLowerCase().contains(lowerQuery),
        )
        .map((entry) => entry.id)
        .toList();

    if (_chatSearchMatchIds.isEmpty) {
      _chatSearchCurrentMatch = 0;
    } else {
      _chatSearchCurrentMatch = _chatSearchCurrentMatch.clamp(
        0,
        _chatSearchMatchIds.length - 1,
      );
    }
  }

  void _clearClassicSearchMatches() {
    _classicSearchMatches = [];
    _classicSearchCurrentMatch = 0;
    _classicController.highlightedRanges = [];
  }

  void _updateClassicSearchMatches(String query) {
    final text = _classicController.text;
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || text.isEmpty) {
      _clearClassicSearchMatches();
      return;
    }

    final matches = <TextRange>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = trimmedQuery.toLowerCase();
    var start = 0;
    while (start < lowerText.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(TextRange(start: index, end: index + lowerQuery.length));
      start = index + lowerQuery.length;
    }

    _classicSearchMatches = matches;
    if (matches.isEmpty) {
      _classicSearchCurrentMatch = 0;
    } else {
      _classicSearchCurrentMatch = _classicSearchCurrentMatch.clamp(
        0,
        matches.length - 1,
      );
    }
    _classicController.highlightedRanges = matches;
  }

  void _goToClassicSearchMatch(int direction) {
    if (_classicSearchMatches.isEmpty) return;
    setState(() {
      _classicSearchCurrentMatch =
          (_classicSearchCurrentMatch + direction) %
          _classicSearchMatches.length;
      if (_classicSearchCurrentMatch < 0) {
        _classicSearchCurrentMatch = _classicSearchMatches.length - 1;
      }
    });

    final range = _classicSearchMatches[_classicSearchCurrentMatch];
    _classicController.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );
  }

  void _goToChatSearchMatch(int direction) {
    if (_chatSearchMatchIds.isEmpty) return;
    setState(() {
      _chatSearchCurrentMatch =
          (_chatSearchCurrentMatch + direction) % _chatSearchMatchIds.length;
      if (_chatSearchCurrentMatch < 0) {
        _chatSearchCurrentMatch = _chatSearchMatchIds.length - 1;
      }
    });
    _scrollToEntry(
      _chatSearchMatchIds[_chatSearchCurrentMatch],
      clearSearch: false,
    );
  }

  Future<void> _openNotebookDetails() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => NotebookDetailsScreen(notebook: _notebook),
      ),
    );
    if (!mounted) return;

    final updated = await context.read<NotebooksProvider>().getNotebook(
      _notebook.id,
    );
    if (updated != null && mounted) {
      setState(() => _notebook = updated);
    }

    if (result != null && mounted) {
      _scrollToEntry(result);
    }
  }

  void _showFullScreenImage(Entry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.draw_outlined, color: Colors.white),
                tooltip: 'Edit drawing',
                onPressed: () {
                  Navigator.pop(context);
                  _annotateEntryImage(entry);
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(entry.imagePath!))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notebookColor = NotebookColors.fromHex(_notebook.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBackground = Color.lerp(
      Theme.of(context).scaffoldBackgroundColor,
      notebookColor,
      isDark ? 0.13 : 0.16,
    )!;

    return PopScope(
      canPop: !_isSelectingEntries && !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectingEntries) {
          _clearEntrySelection();
        } else if (!didPop && _isSearching) {
          _toggleSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: !_isSearching,
          leading: _isSelectingEntries
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear selection',
                  onPressed: _clearEntrySelection,
                )
              : _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close search',
                  onPressed: _toggleSearch,
                )
              : null,
          title: _isSelectingEntries
              ? Text(
                  '${_selectedEntryIds.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : _isSearching
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search in notebook...',
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: _performSearch,
                )
              : InkWell(
                  onTap: _openNotebookDetails,
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 156),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Text(
                        _notebook.title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
          actions: [
            if (_isSelectingEntries)
              Consumer<EntriesProvider>(
                builder: (context, provider, _) {
                  final visibleEntries = _visibleChatEntries(provider);
                  final allVisibleSelected =
                      visibleEntries.isNotEmpty &&
                      visibleEntries.every(
                        (entry) => _selectedEntryIds.contains(entry.id),
                      );
                  final selectedEntries = visibleEntries
                      .where((entry) => _selectedEntryIds.contains(entry.id))
                      .toList();
                  final selectedAreAllStarred =
                      selectedEntries.isNotEmpty &&
                      selectedEntries.every((entry) => entry.isStarred);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedEntries.length == 1 &&
                          selectedEntries.first.hasImage)
                        IconButton(
                          icon: const Icon(Icons.draw_outlined),
                          tooltip: 'Edit drawing',
                          onPressed: () {
                            final entry = selectedEntries.first;
                            _clearEntrySelection();
                            _annotateEntryImage(entry);
                          },
                        ),
                      if (selectedEntries.length == 1)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit entry',
                          onPressed: () {
                            final entry = selectedEntries.first;
                            _clearEntrySelection();
                            _navigateToEdit(entry);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy',
                        onPressed: () => _copySelectedEntries(visibleEntries),
                      ),
                      IconButton(
                        icon: Icon(
                          selectedAreAllStarred
                              ? Icons.star
                              : Icons.star_border,
                        ),
                        tooltip: selectedAreAllStarred
                            ? 'Remove star'
                            : 'Star selected',
                        onPressed: () => _setSelectedEntriesStarred(
                          visibleEntries,
                          !selectedAreAllStarred,
                        ),
                      ),
                      if (selectedEntries.length != 1)
                        IconButton(
                          icon: Icon(
                            allVisibleSelected
                                ? Icons.deselect
                                : Icons.select_all,
                          ),
                          tooltip: allVisibleSelected
                              ? 'Clear selection'
                              : 'Select visible',
                          onPressed: allVisibleSelected
                              ? _clearEntrySelection
                              : () => _selectVisibleEntries(visibleEntries),
                        ),
                      if (selectedEntries.length == 1)
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'More',
                          onPressed: () => _showEntryOptions(
                            selectedEntries.first,
                            includePrimaryActions: false,
                          ),
                        ),
                    ],
                  );
                },
              )
            else if (_isSearching)
              if (_notebook.entryStyle == NotebookEntryStyles.classic)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _classicSearchMatches.isEmpty
                          ? '0/0'
                          : '${_classicSearchCurrentMatch + 1}/${_classicSearchMatches.length}',
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: 'Previous match',
                      onPressed: _classicSearchMatches.isEmpty
                          ? null
                          : () => _goToClassicSearchMatch(-1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Next match',
                      onPressed: _classicSearchMatches.isEmpty
                          ? null
                          : () => _goToClassicSearchMatch(1),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _chatSearchMatchIds.isEmpty
                          ? '0/0'
                          : '${_chatSearchCurrentMatch + 1}/${_chatSearchMatchIds.length}',
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: 'Previous match',
                      onPressed: _chatSearchMatchIds.isEmpty
                          ? null
                          : () => _goToChatSearchMatch(-1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Next match',
                      onPressed: _chatSearchMatchIds.isEmpty
                          ? null
                          : () => _goToChatSearchMatch(1),
                    ),
                  ],
                ),
            if (!_isSearching && !_isSelectingEntries) ...[
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'search':
                      _toggleSearch();
                      break;
                    case 'starred':
                      setState(() => _showStarredOnly = !_showStarredOnly);
                      break;
                    case 'goToDate':
                      _showJumpToDatePicker();
                      break;
                    case 'formatting':
                      setState(() {
                        _showClassicFormattingBar = !_showClassicFormattingBar;
                      });
                      break;
                    case 'edit':
                      _showEditNotebookDialog();
                      break;
                    case 'archive':
                      final navigator = Navigator.of(context);
                      await context.read<NotebooksProvider>().toggleArchive(
                        _notebook.id,
                      );
                      if (mounted) navigator.pop();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'search', child: Text('Search')),
                  if (_notebook.entryStyle == NotebookEntryStyles.chat)
                    PopupMenuItem(
                      value: 'starred',
                      child: Text(
                        _showStarredOnly
                            ? 'Show All Entries'
                            : 'Starred Entries',
                      ),
                    ),
                  if (_notebook.entryStyle == NotebookEntryStyles.chat)
                    const PopupMenuItem(
                      value: 'goToDate',
                      child: Text('Go to Date'),
                    ),
                  if (_notebook.entryStyle == NotebookEntryStyles.classic)
                    PopupMenuItem(
                      value: 'formatting',
                      child: Text(
                        _showClassicFormattingBar
                            ? 'Hide Formatting'
                            : 'Show Formatting',
                      ),
                    ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(_notebook.isArchived ? 'Unarchive' : 'Archive'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Notebook'),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: ColoredBox(
          color: chatBackground,
          child: Column(
            children: [
              Expanded(
                child: Consumer<EntriesProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_notebook.entryStyle == NotebookEntryStyles.classic) {
                      if (_classicEntryId == null &&
                          _classicController.text.isEmpty &&
                          provider.entries.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _syncClassicEditor();
                        });
                      }
                      return _buildClassicEditor(notebookColor);
                    }

                    final entries = _visibleChatEntries(provider);

                    if (entries.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Entries from provider are DESC (newest first)
                    // With reverse:true ListView, index 0 appears at bottom
                    // So for time-based spacing, we compare each entry with the one BELOW it
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        // The entry that appears ABOVE this one visually (older in time)
                        final olderEntry = index < entries.length - 1
                            ? entries[index + 1]
                            : null;
                        // The entry that appears BELOW this one visually (newer in time)
                        final newerEntry = index > 0
                            ? entries[index - 1]
                            : null;

                        return _buildEntryItem(entry, olderEntry, newerEntry);
                      },
                    );
                  },
                ),
              ),
              if (_notebook.entryStyle == NotebookEntryStyles.chat)
                InputBar(
                  onSend: _handleSend,
                  enabled: !_isSearching && !_isSelectingEntries,
                  notebookColor: notebookColor,
                ),
              if (_notebook.entryStyle == NotebookEntryStyles.classic &&
                  _showClassicFormattingBar)
                _buildClassicFormattingBar(Theme.of(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'No results found' : 'No entries yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (!_isSearching) ...[
            const SizedBox(height: 8),
            Text(
              'Start typing below to add your first entry',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassicEditor(Color notebookColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final editorColor = Color.lerp(
      theme.colorScheme.surface,
      notebookColor,
      isDark ? 0.10 : 0.08,
    )!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Material(
        color: editorColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _classicController,
                autofocus: !_isSearching,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                decoration: InputDecoration(
                  hintText: 'Start writing...',
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassicFormattingBar(ThemeData theme) {
    final dividerColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 8,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: [
              _buildClassicToolbarButton(
                icon: Icons.arrow_back,
                tooltip: 'Undo',
                onPressed: _classicUndoStack.isEmpty ? null : _undoClassicEdit,
              ),
              _buildClassicToolbarButton(
                icon: Icons.arrow_forward,
                tooltip: 'Redo',
                onPressed: _classicRedoStack.isEmpty ? null : _redoClassicEdit,
              ),
              _buildClassicToolbarDivider(theme),
              _buildClassicToolbarButton(
                icon: Icons.format_bold,
                tooltip: 'Bold',
                selected: _classicController.activeInlineFormats.contains(
                  _ClassicInlineFormat.bold,
                ),
                onPressed: () =>
                    _applyInlineClassicFormat(_ClassicInlineFormat.bold),
              ),
              _buildClassicToolbarButton(
                icon: Icons.format_italic,
                tooltip: 'Italic',
                selected: _classicController.activeInlineFormats.contains(
                  _ClassicInlineFormat.italic,
                ),
                onPressed: () =>
                    _applyInlineClassicFormat(_ClassicInlineFormat.italic),
              ),
              _buildClassicToolbarButton(
                icon: Icons.code,
                tooltip: 'Inline code',
                selected: _classicController.activeInlineFormats.contains(
                  _ClassicInlineFormat.code,
                ),
                onPressed: () =>
                    _applyInlineClassicFormat(_ClassicInlineFormat.code),
              ),
              _buildClassicToolbarDivider(theme),
              _buildClassicToolbarButton(
                icon: Icons.title,
                tooltip: 'Heading',
                selected:
                    _classicController.activeLineFormat ==
                    _ClassicLineFormat.heading,
                onPressed: () =>
                    _applyLineClassicFormat(_ClassicLineFormat.heading),
              ),
              _buildClassicToolbarButton(
                icon: Icons.format_list_bulleted,
                tooltip: 'Bullet list',
                selected:
                    _classicController.activeLineFormat ==
                    _ClassicLineFormat.bullet,
                onPressed: () =>
                    _applyLineClassicFormat(_ClassicLineFormat.bullet),
              ),
              _buildClassicToolbarButton(
                icon: Icons.format_quote,
                tooltip: 'Quote',
                selected:
                    _classicController.activeLineFormat ==
                    _ClassicLineFormat.quote,
                onPressed: () =>
                    _applyLineClassicFormat(_ClassicLineFormat.quote),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassicToolbarDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
    );
  }

  Widget _buildClassicToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        foregroundColor: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildEntryItem(Entry entry, Entry? olderEntry, Entry? newerEntry) {
    final widgets = <Widget>[];

    // Date header: show when this is the first entry of a new day
    // (i.e., the older entry is on a different day or doesn't exist)
    final needsDateHeader =
        olderEntry == null ||
        !TimeUtils.isSameDay(entry.displayTime, olderEntry.displayTime);

    // Calculate spacing ABOVE this entry (gap from older entry)
    // This creates visual separation between time-distant entries
    double aboveSpacing = 0;
    if (olderEntry != null &&
        TimeUtils.isSameDay(entry.displayTime, olderEntry.displayTime)) {
      final gapMinutes = TimeUtils.getTimeGapMinutes(
        olderEntry.displayTime,
        entry.displayTime,
      );
      // Dynamic spacing based on time gap - bigger values for more noticeable effect
      if (gapMinutes >= TimeGaps.medium) {
        aboveSpacing = 32; // 2+ hours gap - very noticeable
      } else if (gapMinutes >= TimeGaps.small) {
        aboveSpacing = 18; // 30min - 2hr gap
      } else if (gapMinutes >= TimeGaps.minimal) {
        aboveSpacing = 8; // 5-30min gap
      }
    }

    // Build widgets in visual order (top to bottom)
    // Date header first (if needed)
    if (needsDateHeader) {
      widgets.add(DateHeader(date: TimeUtils.getDateHeader(entry.displayTime)));
      widgets.add(const SizedBox(height: 12));
    }

    // Time-based spacing above entry
    if (aboveSpacing > 0 && !needsDateHeader) {
      widgets.add(SizedBox(height: aboveSpacing));
    }

    widgets.add(
      EntryBubble(
        entry: entry,
        showTimestamp: true,
        notebookColor: NotebookColors.fromHex(_notebook.color),
        isSelected: _selectedEntryIds.contains(entry.id),
        searchQuery:
            _isSearching && _notebook.entryStyle == NotebookEntryStyles.chat
            ? _searchController.text
            : null,
        onTap: () {
          if (_isSelectingEntries) {
            _toggleEntrySelection(entry);
            return;
          }

          if (_showStarredOnly || _isSearching) {
            _scrollToEntry(entry.id);
          } else {
            _navigateToEdit(entry);
          }
        },
        onLongPress: () => _toggleEntrySelection(entry),
        onImageTap: entry.hasImage
            ? () {
                if (_isSelectingEntries) {
                  _toggleEntrySelection(entry);
                } else {
                  _showFullScreenImage(entry);
                }
              }
            : null,
        onImageLongPress: entry.hasImage
            ? () => _toggleEntrySelection(entry)
            : null,
      ),
    );

    // Return column with widgets in visual order (top to bottom)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  void _showEditNotebookDialog() {
    final titleController = TextEditingController(text: _notebook.title);
    String selectedColor = _notebook.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Edit Notebook',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Notebook Name',
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
                  const SizedBox(height: 20),
                  Text(
                    'Choose Color',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: NotebookColors.colors.map((color) {
                      final hex = NotebookColors.toHex(color);
                      final isSelected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = hex),
                        child: AnimatedContainer(
                          duration: quickAnimation,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final updatedNotebook = _notebook.copyWith(
                          title: title,
                          color: selectedColor,
                          updatedAt: DateTime.now(),
                        );

                        await context.read<NotebooksProvider>().updateNotebook(
                          updatedNotebook,
                        );

                        setState(() => _notebook = updatedNotebook);

                        if (mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
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

class _ClassicStyleRange {
  final int start;
  final int end;
  final _ClassicInlineFormat format;

  const _ClassicStyleRange({
    required this.start,
    required this.end,
    required this.format,
  });

  _ClassicStyleRange copyWith({int? start, int? end}) {
    return _ClassicStyleRange(
      start: start ?? this.start,
      end: end ?? this.end,
      format: format,
    );
  }
}

class _ClassicLineStyle {
  final int start;
  final int end;
  final _ClassicLineFormat format;

  const _ClassicLineStyle({
    required this.start,
    required this.end,
    required this.format,
  });

  _ClassicLineStyle copyWith({int? start, int? end}) {
    return _ClassicLineStyle(
      start: start ?? this.start,
      end: end ?? this.end,
      format: format,
    );
  }
}

class _ClassicEditorSnapshot {
  final TextEditingValue value;
  final List<_ClassicStyleRange> inlineStyles;
  final List<_ClassicLineStyle> lineStyles;

  const _ClassicEditorSnapshot({
    required this.value,
    required this.inlineStyles,
    required this.lineStyles,
  });

  factory _ClassicEditorSnapshot.empty() {
    return const _ClassicEditorSnapshot(
      value: TextEditingValue.empty,
      inlineStyles: [],
      lineStyles: [],
    );
  }

  String get text => value.text;

  bool hasSameContent(_ClassicEditorSnapshot other) {
    if (value.text != other.value.text ||
        inlineStyles.length != other.inlineStyles.length ||
        lineStyles.length != other.lineStyles.length) {
      return false;
    }
    for (var i = 0; i < inlineStyles.length; i++) {
      final a = inlineStyles[i];
      final b = other.inlineStyles[i];
      if (a.start != b.start || a.end != b.end || a.format != b.format) {
        return false;
      }
    }
    for (var i = 0; i < lineStyles.length; i++) {
      final a = lineStyles[i];
      final b = other.lineStyles[i];
      if (a.start != b.start || a.end != b.end || a.format != b.format) {
        return false;
      }
    }
    return true;
  }
}

class _ClassicRichTextController extends TextEditingController {
  List<_ClassicStyleRange> inlineStyles = [];
  List<_ClassicLineStyle> lineStyles = [];
  List<TextRange> highlightedRanges = [];
  final Set<_ClassicInlineFormat> activeInlineFormats = {};
  _ClassicLineFormat? activeLineFormat;

  _ClassicEditorSnapshot snapshot() {
    return _ClassicEditorSnapshot(
      value: value,
      inlineStyles: List<_ClassicStyleRange>.from(inlineStyles),
      lineStyles: List<_ClassicLineStyle>.from(lineStyles),
    );
  }

  void restore(_ClassicEditorSnapshot snapshot) {
    value = snapshot.value;
    inlineStyles = List<_ClassicStyleRange>.from(snapshot.inlineStyles);
    lineStyles = List<_ClassicLineStyle>.from(snapshot.lineStyles);
    activeInlineFormats.clear();
    activeLineFormat = null;
  }

  void reflowInlineFormats(String previousText) {
    final currentText = text;
    final delta = currentText.length - previousText.length;
    if (delta == 0) return;

    var prefix = 0;
    final minLength = previousText.length < currentText.length
        ? previousText.length
        : currentText.length;
    while (prefix < minLength &&
        previousText.codeUnitAt(prefix) == currentText.codeUnitAt(prefix)) {
      prefix++;
    }

    inlineStyles = inlineStyles
        .map((range) {
          if (prefix <= range.start) {
            return range.copyWith(
              start: (range.start + delta).clamp(0, currentText.length),
              end: (range.end + delta).clamp(0, currentText.length),
            );
          }
          if (prefix < range.end) {
            return range.copyWith(
              end: (range.end + delta).clamp(range.start, currentText.length),
            );
          }
          return range;
        })
        .where((range) => range.end > range.start)
        .toList();
    if (delta > 0 && activeInlineFormats.isNotEmpty) {
      for (final format in activeInlineFormats) {
        inlineStyles.add(
          _ClassicStyleRange(
            start: prefix,
            end: prefix + delta,
            format: format,
          ),
        );
      }
      inlineStyles = _mergeInlineStyles(inlineStyles);
    }
    if (delta > 0 && activeLineFormat != null) {
      _applyLineFormatAtOffset(prefix, activeLineFormat!);
    }
    lineStyles = _normalizeLineStyles(lineStyles, currentText);
  }

  void toggleInlineFormat(_ClassicInlineFormat format) {
    final selection = value.selection;
    if (!selection.isValid) return;

    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;
    if (start == end) {
      if (!activeInlineFormats.add(format)) {
        activeInlineFormats.remove(format);
      }
      notifyListeners();
      return;
    }

    final existingIndex = inlineStyles.indexWhere(
      (range) =>
          range.format == format && range.start <= start && range.end >= end,
    );
    if (existingIndex >= 0) {
      final existing = inlineStyles.removeAt(existingIndex);
      if (existing.start < start) {
        inlineStyles.add(existing.copyWith(end: start));
      }
      if (existing.end > end) {
        inlineStyles.add(existing.copyWith(start: end));
      }
    } else {
      inlineStyles.add(
        _ClassicStyleRange(start: start, end: end, format: format),
      );
    }
    inlineStyles = _mergeInlineStyles(inlineStyles);
    notifyListeners();
  }

  void toggleLineFormat(_ClassicLineFormat format) {
    final selection = value.selection;
    if (!selection.isValid) return;

    final textValue = text;
    final selectionStart = selection.start < selection.end
        ? selection.start
        : selection.end;
    final selectionEnd = selection.start < selection.end
        ? selection.end
        : selection.start;
    final firstLineStart = selectionStart == 0
        ? 0
        : textValue.lastIndexOf('\n', selectionStart - 1) + 1;
    final selectedLineEnd = selectionEnd < textValue.length
        ? textValue.indexOf('\n', selectionEnd)
        : textValue.length;
    final lastLineEnd = selectedLineEnd == -1
        ? textValue.length
        : selectedLineEnd;
    final bounds = _lineBounds(textValue, firstLineStart, lastLineEnd);
    if (selectionStart == selectionEnd) {
      final hasCurrentLineFormat = lineStyles.any(
        (style) =>
            style.format == format &&
            style.start == bounds.first.$1 &&
            style.end == bounds.first.$2,
      );
      if (hasCurrentLineFormat || activeLineFormat == format) {
        var adjustedText = textValue;
        var selectionOffset = selection.extentOffset;
        if (format == _ClassicLineFormat.bullet &&
            adjustedText
                .substring(bounds.first.$1, bounds.first.$2)
                .startsWith('• ')) {
          adjustedText = adjustedText.replaceRange(
            bounds.first.$1,
            bounds.first.$1 + 2,
            '',
          );
          selectionOffset = (selectionOffset - 2).clamp(0, adjustedText.length);
          value = value.copyWith(
            text: adjustedText,
            selection: TextSelection.collapsed(offset: selectionOffset),
            composing: TextRange.empty,
          );
        }
        lineStyles.removeWhere(
          (style) =>
              style.start == bounds.first.$1 && style.end == bounds.first.$2,
        );
        activeLineFormat = null;
      } else {
        var lineStart = bounds.first.$1;
        var lineEnd = bounds.first.$2;
        if (format == _ClassicLineFormat.bullet &&
            !textValue.substring(lineStart, lineEnd).startsWith('• ')) {
          final updatedText = textValue.replaceRange(
            lineStart,
            lineStart,
            '• ',
          );
          value = value.copyWith(
            text: updatedText,
            selection: TextSelection.collapsed(
              offset: selection.extentOffset + 2,
            ),
            composing: TextRange.empty,
          );
          lineEnd += 2;
        }
        lineStyles.removeWhere(
          (style) => style.start == lineStart && style.end == lineEnd,
        );
        lineStyles.add(
          _ClassicLineStyle(start: lineStart, end: lineEnd, format: format),
        );
        activeLineFormat = format;
      }
      lineStyles = _normalizeLineStyles(lineStyles, text);
      notifyListeners();
      return;
    }

    final allLinesHaveFormat = bounds.every(
      (bound) => lineStyles.any(
        (style) =>
            style.format == format &&
            style.start == bound.$1 &&
            style.end == bound.$2,
      ),
    );

    lineStyles.removeWhere(
      (style) =>
          style.start >= firstLineStart &&
          style.end <= lastLineEnd &&
          (allLinesHaveFormat || style.format != format),
    );

    if (!allLinesHaveFormat) {
      for (final bound in bounds) {
        lineStyles.add(
          _ClassicLineStyle(start: bound.$1, end: bound.$2, format: format),
        );
      }
    }
    lineStyles = _normalizeLineStyles(lineStyles, textValue);
    notifyListeners();
  }

  void _applyLineFormatAtOffset(int offset, _ClassicLineFormat format) {
    final textValue = text;
    final lineStart = offset == 0
        ? 0
        : textValue.lastIndexOf('\n', offset - 1) + 1;
    final nextNewline = textValue.indexOf('\n', lineStart);
    final lineEnd = nextNewline == -1 ? textValue.length : nextNewline;
    lineStyles.removeWhere(
      (style) => style.start == lineStart && style.end == lineEnd,
    );
    lineStyles.add(
      _ClassicLineStyle(start: lineStart, end: lineEnd, format: format),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final textValue = text;
    if (textValue.isEmpty) return TextSpan(style: baseStyle, text: '');

    final spans = <TextSpan>[];
    for (var i = 0; i < textValue.length; i++) {
      final lineStyle = lineStyles
          .where((range) => i >= range.start && i < range.end)
          .firstOrNull;
      final activeInlineStyles = inlineStyles
          .where((range) => i >= range.start && i < range.end)
          .map((range) => range.format)
          .toSet();
      final isHighlighted = highlightedRanges.any(
        (range) => i >= range.start && i < range.end,
      );
      final next = _nextStyleBoundary(i, textValue.length);
      spans.add(
        TextSpan(
          text: textValue.substring(i, next),
          style: _styleFor(
            baseStyle,
            lineStyle?.format,
            activeInlineStyles,
            isHighlighted,
          ),
        ),
      );
      i = next - 1;
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  int _nextStyleBoundary(int offset, int textLength) {
    var next = textLength;
    for (final range in inlineStyles) {
      if (range.start > offset && range.start < next) next = range.start;
      if (range.end > offset && range.end < next) next = range.end;
    }
    for (final range in lineStyles) {
      if (range.start > offset && range.start < next) next = range.start;
      if (range.end > offset && range.end < next) next = range.end;
    }
    for (final range in highlightedRanges) {
      if (range.start > offset && range.start < next) next = range.start;
      if (range.end > offset && range.end < next) next = range.end;
    }
    return next;
  }

  TextStyle _styleFor(
    TextStyle baseStyle,
    _ClassicLineFormat? lineFormat,
    Set<_ClassicInlineFormat> inlineFormats,
    bool isHighlighted,
  ) {
    var result = baseStyle;
    if (lineFormat == _ClassicLineFormat.heading) {
      result = result.copyWith(
        fontSize: (result.fontSize ?? 16) + 6,
        fontWeight: FontWeight.w700,
        height: 1.35,
      );
    } else if (lineFormat == _ClassicLineFormat.quote) {
      result = result.copyWith(
        fontStyle: FontStyle.italic,
        color: result.color?.withValues(alpha: 0.72),
      );
    }

    if (inlineFormats.contains(_ClassicInlineFormat.bold)) {
      result = result.copyWith(fontWeight: FontWeight.w700);
    }
    if (inlineFormats.contains(_ClassicInlineFormat.italic)) {
      result = result.copyWith(fontStyle: FontStyle.italic);
    }
    if (inlineFormats.contains(_ClassicInlineFormat.code)) {
      result = result.copyWith(
        fontFamily: 'monospace',
        backgroundColor: (result.color ?? Colors.black).withValues(alpha: 0.08),
      );
    }
    if (isHighlighted) {
      result = result.copyWith(
        backgroundColor: Colors.amber.withValues(alpha: 0.45),
      );
    }
    return result;
  }
}

class _ClassicMarkdownCodec {
  static _ClassicEditorSnapshot decode(String markdown) {
    final inlineStyles = <_ClassicStyleRange>[];
    final lineStyles = <_ClassicLineStyle>[];
    final plain = StringBuffer();
    final lines = markdown.split('\n');

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      var line = lines[lineIndex];
      final lineStart = plain.length;
      _ClassicLineFormat? lineFormat;

      if (line.startsWith('# ')) {
        lineFormat = _ClassicLineFormat.heading;
        line = line.substring(2);
      } else if (line.startsWith('- ')) {
        lineFormat = _ClassicLineFormat.bullet;
        line = '• ${line.substring(2)}';
      } else if (line.startsWith('> ')) {
        lineFormat = _ClassicLineFormat.quote;
        line = line.substring(2);
      }

      _appendInlineDecoded(line, plain, inlineStyles);
      final lineEnd = plain.length;
      if (lineFormat != null) {
        lineStyles.add(
          _ClassicLineStyle(start: lineStart, end: lineEnd, format: lineFormat),
        );
      }
      if (lineIndex < lines.length - 1) {
        plain.write('\n');
      }
    }

    return _ClassicEditorSnapshot(
      value: TextEditingValue(text: plain.toString()),
      inlineStyles: _mergeInlineStyles(inlineStyles),
      lineStyles: _normalizeLineStyles(lineStyles, plain.toString()),
    );
  }

  static String encode(_ClassicEditorSnapshot snapshot) {
    final text = snapshot.text;
    final inlineStyles = _mergeInlineStyles(snapshot.inlineStyles);
    final lineStyles = _normalizeLineStyles(snapshot.lineStyles, text);
    final result = StringBuffer();

    for (final bound in _lineBounds(text, 0, text.length)) {
      if (result.isNotEmpty) result.write('\n');
      final lineStart = bound.$1;
      final lineEnd = bound.$2;
      final lineStyle = lineStyles
          .where((style) => style.start == lineStart && style.end == lineEnd)
          .firstOrNull;

      switch (lineStyle?.format) {
        case _ClassicLineFormat.heading:
          result.write('# ');
          break;
        case _ClassicLineFormat.bullet:
          result.write('- ');
          break;
        case _ClassicLineFormat.quote:
          result.write('> ');
          break;
        case null:
          break;
      }

      result.write(
        _encodeInlineText(
          lineStyle?.format == _ClassicLineFormat.bullet &&
                  text.substring(lineStart, lineEnd).startsWith('• ')
              ? text.substring(lineStart + 2, lineEnd)
              : text.substring(lineStart, lineEnd),
          lineStyle?.format == _ClassicLineFormat.bullet &&
                  text.substring(lineStart, lineEnd).startsWith('• ')
              ? lineStart + 2
              : lineStart,
          inlineStyles,
        ),
      );
    }

    return result.toString();
  }

  static void _appendInlineDecoded(
    String markdown,
    StringBuffer plain,
    List<_ClassicStyleRange> inlineStyles,
  ) {
    final active = <_ClassicInlineFormat, int>{};
    var i = 0;
    while (i < markdown.length) {
      final marker = _markerAt(markdown, i);
      if (marker != null) {
        final start = active.remove(marker.$1);
        if (start == null) {
          active[marker.$1] = plain.length;
        } else if (plain.length > start) {
          inlineStyles.add(
            _ClassicStyleRange(
              start: start,
              end: plain.length,
              format: marker.$1,
            ),
          );
        }
        i += marker.$2.length;
      } else {
        plain.write(markdown[i]);
        i++;
      }
    }
  }

  static String _encodeInlineText(
    String line,
    int globalOffset,
    List<_ClassicStyleRange> inlineStyles,
  ) {
    final markers = <int, List<String>>{};
    for (final style in inlineStyles) {
      final start = style.start.clamp(globalOffset, globalOffset + line.length);
      final end = style.end.clamp(globalOffset, globalOffset + line.length);
      if (end <= start) continue;
      markers
          .putIfAbsent(start - globalOffset, () => [])
          .add(_markerFor(style.format));
      markers
          .putIfAbsent(end - globalOffset, () => [])
          .insert(0, _markerFor(style.format));
    }

    final result = StringBuffer();
    for (var i = 0; i <= line.length; i++) {
      for (final marker in markers[i] ?? const <String>[]) {
        result.write(marker);
      }
      if (i < line.length) result.write(line[i]);
    }
    return result.toString();
  }

  static (_ClassicInlineFormat, String)? _markerAt(String text, int offset) {
    if (text.startsWith('**', offset)) {
      return (_ClassicInlineFormat.bold, '**');
    }
    if (text.startsWith('`', offset)) {
      return (_ClassicInlineFormat.code, '`');
    }
    if (text.startsWith('*', offset)) {
      return (_ClassicInlineFormat.italic, '*');
    }
    return null;
  }

  static String _markerFor(_ClassicInlineFormat format) {
    switch (format) {
      case _ClassicInlineFormat.bold:
        return '**';
      case _ClassicInlineFormat.italic:
        return '*';
      case _ClassicInlineFormat.code:
        return '`';
    }
  }
}

List<_ClassicStyleRange> _mergeInlineStyles(List<_ClassicStyleRange> styles) {
  final sorted = [...styles]
    ..sort((a, b) {
      final formatCompare = a.format.index.compareTo(b.format.index);
      if (formatCompare != 0) return formatCompare;
      return a.start.compareTo(b.start);
    });
  final merged = <_ClassicStyleRange>[];
  for (final style in sorted) {
    if (style.end <= style.start) continue;
    if (merged.isNotEmpty &&
        merged.last.format == style.format &&
        style.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(
        last.copyWith(end: style.end > last.end ? style.end : last.end),
      );
    } else {
      merged.add(style);
    }
  }
  return merged;
}

List<_ClassicLineStyle> _normalizeLineStyles(
  List<_ClassicLineStyle> styles,
  String text,
) {
  final normalized = <_ClassicLineStyle>[];
  for (final style in styles) {
    if (style.start < 0 || style.start > text.length) continue;
    final lineStart = style.start == 0
        ? 0
        : text.lastIndexOf('\n', style.start - 1) + 1;
    final nextNewline = text.indexOf('\n', lineStart);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    normalized.removeWhere(
      (existing) => existing.start == lineStart && existing.end == lineEnd,
    );
    normalized.add(style.copyWith(start: lineStart, end: lineEnd));
  }
  return normalized;
}

List<(int, int)> _lineBounds(String text, int start, int end) {
  final bounds = <(int, int)>[];
  var lineStart = start;
  while (lineStart <= end) {
    final nextNewline = text.indexOf('\n', lineStart);
    final lineEnd = nextNewline == -1 || nextNewline > end ? end : nextNewline;
    bounds.add((lineStart, lineEnd));
    if (nextNewline == -1 || nextNewline >= end) break;
    lineStart = nextNewline + 1;
  }
  return bounds;
}
