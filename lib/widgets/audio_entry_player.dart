import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../utils/duration_utils.dart';

class AudioEntryPlayer extends StatefulWidget {
  final String audioPath;
  final int? durationMs;
  final Color accentColor;
  final bool compact;
  final bool embedded;

  const AudioEntryPlayer({
    super.key,
    required this.audioPath,
    required this.accentColor,
    this.durationMs,
    this.compact = false,
    this.embedded = false,
  });

  @override
  State<AudioEntryPlayer> createState() => _AudioEntryPlayerState();
}

class _AudioEntryPlayerState extends State<AudioEntryPlayer> {
  late final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;

  Duration get _duration => Duration(milliseconds: widget.durationMs ?? 0);
  bool get _isPlaying => _state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (!await File(widget.audioPath).exists()) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.audioPath));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _duration;
    final positionText = _position > Duration.zero && duration > Duration.zero
        ? DurationUtils.formatCompact(_position)
        : DurationUtils.formatCompact(duration);

    return Container(
      constraints: widget.compact
          ? const BoxConstraints(minHeight: 44)
          : const BoxConstraints(minHeight: 52),
      padding: widget.embedded
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 10,
              vertical: widget.compact ? 6 : 8,
            ),
      decoration: widget.embedded
          ? null
          : BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.20),
              ),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filled(
            visualDensity: VisualDensity.compact,
            onPressed: _togglePlayback,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 8),
          Icon(Icons.graphic_eq, color: widget.accentColor),
          const SizedBox(width: 8),
          Text(
            positionText,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
