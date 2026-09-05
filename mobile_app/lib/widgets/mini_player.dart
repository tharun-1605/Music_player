import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  bool _isDragging = false;
  double _dragProgress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final audioHandler = ref.read(audioPlayerServiceProvider);
    
    _positionSub = audioHandler.player.positionStream.listen((pos) {
      if (!_isDragging && mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    });

    _durationSub = audioHandler.player.durationStream.listen((dur) {
      if (mounted) {
        setState(() {
          _totalDuration = dur ?? Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details, BoxConstraints constraints) {
    setState(() {
      _isDragging = true;
      _updateDragProgress(details.localPosition.dx, constraints.maxWidth);
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details, BoxConstraints constraints) {
    setState(() {
      _updateDragProgress(details.localPosition.dx, constraints.maxWidth);
    });
  }

  void _onLongPressEnd(LongPressEndDetails details, BoxConstraints constraints) {
    final audioHandler = ref.read(audioPlayerServiceProvider);
    if (_totalDuration > Duration.zero) {
      final seekTo = Duration(
        milliseconds: (_dragProgress * _totalDuration.inMilliseconds).toInt(),
      );
      audioHandler.seek(seekTo);
    }
    setState(() {
      _isDragging = false;
    });
  }

  void _updateDragProgress(double localDx, double maxWidth) {
    if (maxWidth <= 0) return;
    double progress = localDx / maxWidth;
    _dragProgress = progress.clamp(0.0, 1.0);
    if (_totalDuration > Duration.zero) {
      _currentPosition = Duration(
        milliseconds: (_dragProgress * _totalDuration.inMilliseconds).toInt(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioPlayerServiceProvider);
    final song = audioHandler.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final playing = audioHandler.player.playing;
    
    double progressPercent = 0.0;
    if (_totalDuration.inMilliseconds > 0) {
      progressPercent = _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
    }
    progressPercent = progressPercent.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onLongPressStart: (details) => _onLongPressStart(details, constraints),
            onLongPressMoveUpdate: (details) => _onLongPressMoveUpdate(details, constraints),
            onLongPressEnd: (details) => _onLongPressEnd(details, constraints),
            onLongPressCancel: () => setState(() => _isDragging = false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border.all(color: Colors.white12, width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ]
                ),
                child: Stack(
                  children: [
                    // Dynamic Progress Background
                    AnimatedContainer(
                      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                      width: constraints.maxWidth * progressPercent,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryAccent.withValues(alpha: 0.3),
                            AppTheme.violetAccent.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    
                    // Top UI Layer
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            ApiConfig.getCoverUrl(song.id),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 48,
                              height: 48,
                              color: Colors.white12,
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          color: Colors.white,
                          iconSize: 26,
                          onPressed: () => audioHandler.skipToPrevious(),
                        ),
                        IconButton(
                          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                          color: AppTheme.primaryAccent,
                          iconSize: 36,
                          onPressed: () {
                            if (playing) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
