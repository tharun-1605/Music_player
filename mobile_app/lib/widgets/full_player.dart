import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../providers/music_providers.dart';
import 'queue_sheet.dart';

class FullPlayerModal extends ConsumerWidget {
  const FullPlayerModal({super.key});

  String _formatTime(Duration duration) {
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final player = playerService.player;
    final currentSong = playerService.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              'PLAYING FROM ALBUM',
              style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              currentSong.album,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const Spacer(),
              // Spotify Artwork Card
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ArtworkImage(
                    songId: currentSong.id,
                    size: MediaQuery.of(context).size.width * 0.82,
                    borderRadius: 16,
                  ),
                ),
              ),
              const Spacer(),
              // Title & Artist & Favorite
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      currentSong.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: currentSong.isFavorite ? AppTheme.primaryAccent : AppTheme.textMuted,
                      size: 28,
                    ),
                    onPressed: () async {
                      final api = ref.read(apiServiceProvider);
                      if (currentSong.isFavorite) {
                        await api.removeFavorite(currentSong.id);
                      } else {
                        await api.addFavorite(currentSong.id);
                      }
                      ref.invalidate(songsProvider);
                      ref.invalidate(favoritesProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Spotify Stream Slider
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final totalDuration = Duration(seconds: currentSong.duration.toInt());

                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble().clamp(0.0, totalDuration.inSeconds.toDouble()),
                          min: 0.0,
                          max: totalDuration.inSeconds > 0 ? totalDuration.inSeconds.toDouble() : 1.0,
                          onChanged: (value) {
                            playerService.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatTime(position), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            Text(_formatTime(totalDuration), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Playback Control Buttons (Spotify Style)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: player.shuffleModeEnabled ? AppTheme.primaryAccent : AppTheme.textMuted,
                      size: 24,
                    ),
                    onPressed: () => playerService.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 38, color: Colors.white),
                    onPressed: () => playerService.skipToPrevious(),
                  ),
                  // Spotify Big Green Circular Play Button
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryAccent, // Spotify Green
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 36,
                          icon: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: Colors.black, // Spotify Black Icon
                          ),
                          onPressed: () {
                            if (playing) {
                              playerService.pause();
                            } else {
                              playerService.play();
                            }
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 38, color: Colors.white),
                    onPressed: () => playerService.skipToNext(),
                  ),
                  IconButton(
                    icon: Icon(
                      player.loopMode == LoopMode.one
                          ? Icons.repeat_one
                          : Icons.repeat,
                      color: player.loopMode != LoopMode.off ? AppTheme.primaryAccent : AppTheme.textMuted,
                      size: 24,
                    ),
                    onPressed: () => playerService.toggleRepeat(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.devices, size: 20, color: AppTheme.textMuted),
                  IconButton(
                    icon: const Icon(Icons.queue_music, size: 22, color: AppTheme.textMuted),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.surfaceColor,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => const QueueSheet(),
                      );
                    },
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
