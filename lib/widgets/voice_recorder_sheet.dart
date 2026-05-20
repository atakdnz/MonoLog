import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/duration_utils.dart';

class VoiceRecordingResult {
  final String path;
  final Duration duration;

  const VoiceRecordingResult({required this.path, required this.duration});
}

class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  bool _isRecording = false;
  bool _isSaving = false;
  String? _recordedPath;
  Duration _duration = Duration.zero;
  DateTime? _recordingStartedAt;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      'monolog_recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _recordingStartedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final startedAt = _recordingStartedAt;
      if (startedAt == null || !mounted) return;
      setState(() => _duration = DateTime.now().difference(startedAt));
    });

    setState(() {
      _isRecording = true;
      _recordedPath = null;
      _duration = Duration.zero;
    });
  }

  Future<void> _stop() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedPath = path;
      if (_recordingStartedAt != null) {
        _duration = DateTime.now().difference(_recordingStartedAt!);
      }
      _recordingStartedAt = null;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (_isRecording) {
      await _recorder.cancel();
    }
    final recordedPath = _recordedPath;
    if (recordedPath != null) {
      try {
        await File(recordedPath).delete();
      } on FileSystemException {
        // The temp file may already be gone if the platform cleaned it up.
      }
    }
    if (mounted) Navigator.pop(context);
  }

  void _save() {
    final path = _recordedPath;
    if (path == null || _duration.inMilliseconds <= 0) return;
    setState(() => _isSaving = true);
    Navigator.pop(
      context,
      VoiceRecordingResult(path: path, duration: _duration),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 44,
              color: _isRecording ? theme.colorScheme.error : primary,
            ),
            const SizedBox(height: 12),
            Text(
              DurationUtils.formatCompact(_duration),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Cancel',
                  onPressed: _isSaving ? null : _cancel,
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: IconButton.filled(
                    tooltip: _isRecording ? 'Stop recording' : 'Record',
                    onPressed: _isSaving
                        ? null
                        : (_isRecording ? _stop : _start),
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                IconButton.filledTonal(
                  tooltip: 'Save',
                  onPressed: _recordedPath == null || _isSaving ? null : _save,
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
