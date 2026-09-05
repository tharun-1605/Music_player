import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/song.dart';
import '../models/lyric.dart';
import '../providers/music_providers.dart';
import '../theme/app_theme.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Song song;

  const LyricsView({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _positionSub;

  int _activeIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;
  int _currentOffsetMs = 0;

  @override
  void initState() {
    super.initState();
    _initPositionSubscription();
  }

  void _initPositionSubscription() {
    final playerService = ref.read(audioPlayerServiceProvider);
    _positionSub = playerService.player.positionStream.listen((position) {
      if (!mounted) return;
      _updateActiveLine(position);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateActiveLine(Duration position) {
    final lyricsAsync = ref.read(lyricsProvider(widget.song.id));
    lyricsAsync.whenData((lyrics) {
      if (!lyrics.isSynced || lyrics.timedLyrics.isEmpty) return;

      final currentMs = position.inMilliseconds + _currentOffsetMs;
      final currentSec = currentMs / 1000.0;

      int newIndex = -1;
      for (int i = 0; i < lyrics.timedLyrics.length; i++) {
        if (currentSec >= lyrics.timedLyrics[i].time) {
          newIndex = i;
        } else {
          break;
        }
      }

      if (newIndex != _activeIndex) {
        setState(() {
          _activeIndex = newIndex;
        });

        if (!_userIsScrolling && _activeIndex >= 0) {
          _scrollToActiveLine(_activeIndex);
        }
      }
    });
  }

  void _scrollToActiveLine(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 64.0;
    final targetOffset = (index * itemHeight) - (MediaQuery.of(context).size.height * 0.25);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserScrollNotification() {
    _userIsScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _userIsScrolling = false;
        });
        if (_activeIndex >= 0) {
          _scrollToActiveLine(_activeIndex);
        }
      }
    });
  }

  void _showAddLyricsDialog(BuildContext context, WidgetRef ref, SongLyrics currentLyrics) {
    String initialText = currentLyrics.plainLyrics ?? '';
    if (initialText.isEmpty && currentLyrics.timedLyrics.isNotEmpty) {
      initialText = currentLyrics.timedLyrics.map((l) {
        final mins = (l.time ~/ 60).toString().padLeft(2, '0');
        final secs = (l.time % 60).toStringAsFixed(2).padLeft(5, '0');
        return '[$mins:$secs] ${l.text}';
      }).join('\n');
    }
    final textController = TextEditingController(text: initialText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add / Edit Lyrics (.LRC)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a .LRC file or paste timed/plain lyrics below:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '[00:12.50] First line of song...\n[00:16.80] Second line...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryAccent,
                            side: const BorderSide(color: AppTheme.primaryAccent),
                          ),
                          icon: const Icon(Icons.file_open, size: 18),
                          label: const Text('Pick .LRC File'),
                          onPressed: () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['lrc', 'txt'],
                                withData: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final file = result.files.first;
                                String content = '';
                                if (file.bytes != null) {
                                  content = utf8.decode(file.bytes!);
                                } else if (file.path != null) {
                                  content = await File(file.path!).readAsString();
                                }
                                if (content.isNotEmpty) {
                                  textController.text = content;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Loaded .LRC file content')),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to read file: $e')),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white30),
                          ),
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Search Online'),
                          onPressed: () async {
                            final api = ref.read(apiServiceProvider);
                            await api.refetchLyrics(widget.song.id);
                            ref.invalidate(lyricsProvider(widget.song.id));
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 8),
                        if (currentLyrics.lyricsSource != 'unavailable')
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                            onPressed: () async {
                              final api = ref.read(apiServiceProvider);
                              await api.deleteLyrics(widget.song.id);
                              ref.invalidate(lyricsProvider(widget.song.id));
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final content = textController.text.trim();
                            if (content.isNotEmpty) {
                              final api = ref.read(apiServiceProvider);
                              await api.saveLyrics(widget.song.id, content, offset: _currentOffsetMs);
                              ref.invalidate(lyricsProvider(widget.song.id));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lyrics saved successfully!'),
                                  ),
                                );
                              }
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.song.id));
    final playerService = ref.watch(audioPlayerServiceProvider);

    return lyricsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      ),
      error: (err, st) => _buildEmptyLyricsView(context, ref, null),
      data: (lyrics) {
        if (!lyrics.isSynced && (lyrics.plainLyrics == null || lyrics.plainLyrics!.trim().isEmpty)) {
          return _buildEmptyLyricsView(context, ref, lyrics);
        }

        if (!lyrics.isSynced) {
          // Plain unsynchronized lyrics view
          return Column(
            children: [
              _buildLyricsHeader(context, ref, lyrics),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: SelectableText(
                    lyrics.plainLyrics ?? 'No lyrics available',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.8,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Synchronized Timed Lyrics View
        return Column(
          children: [
            _buildLyricsHeader(context, ref, lyrics),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo is ScrollStartNotification && scrollInfo.dragDetails != null) {
                    _onUserScrollNotification();
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                  itemCount: lyrics.timedLyrics.length,
                  itemBuilder: (context, index) {
                    final line = lyrics.timedLyrics[index];
                    final isActive = index == _activeIndex;
                    final isPast = index < _activeIndex;

                    return GestureDetector(
                      onTap: () {
                        playerService.seek(Duration(milliseconds: (line.time * 1000).toInt()));
                        setState(() {
                          _activeIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: isActive ? 24 : 19,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : (isPast
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.5)),
                            height: 1.4,
                            shadows: isActive
                                ? [
                                    Shadow(
                                      color: AppTheme.primaryAccent.withValues(alpha: 0.8),
                                      blurRadius: 16,
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            line.text.isEmpty ? '♪' : line.text,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLyricsHeader(BuildContext context, WidgetRef ref, SongLyrics lyrics) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lyrics.lyricsSource.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              // Offset Adjuster
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textMuted),
                tooltip: 'Delay lyrics (-0.5s)',
                onPressed: () async {
                  final newOffset = _currentOffsetMs - 500;
                  setState(() => _currentOffsetMs = newOffset);
                  final api = ref.read(apiServiceProvider);
                  await api.updateLyricsOffset(widget.song.id, newOffset);
                  ref.invalidate(lyricsProvider(widget.song.id));
                },
              ),
              Text(
                '${(_currentOffsetMs / 1000.0).toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.textMuted),
                tooltip: 'Advance lyrics (+0.5s)',
                onPressed: () async {
                  final newOffset = _currentOffsetMs + 500;
                  setState(() => _currentOffsetMs = newOffset);
                  final api = ref.read(apiServiceProvider);
                  await api.updateLyricsOffset(widget.song.id, newOffset);
                  ref.invalidate(lyricsProvider(widget.song.id));
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.white),
            tooltip: 'Add / Edit Lyrics',
            onPressed: () => _showAddLyricsDialog(context, ref, lyrics),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLyricsView(BuildContext context, WidgetRef ref, SongLyrics? lyrics) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lyrics_outlined, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Lyrics unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'No timed .LRC file or embedded lyrics found',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Lyrics', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showAddLyricsDialog(
              context,
              ref,
              lyrics ?? SongLyrics(songId: widget.song.id, lyricsSource: 'unavailable'),
            ),
          ),
        ],
      ),
    );
  }
}
