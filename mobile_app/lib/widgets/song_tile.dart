import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../widgets/stats_for_nerds_modal.dart';
import '../providers/music_providers.dart';
import '../screens/songs/song_info_screen.dart';
import '../screens/player/player_screen.dart';
import '../widgets/add_to_playlist_dialog.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
  });

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final downloadService = ref.watch(downloadServiceProvider);
    final isDownloaded = downloadService.isDownloaded(song.id);

    return InkWell(
      onTap: () {
        onTap();
        PlayerScreen.open(context);
      },
      splashColor: Colors.white10,
      highlightColor: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ArtworkImage(songId: song.id, size: 48, borderRadius: 6),
                if (isPlaying)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.graphic_eq,
                      color: AppTheme.primaryAccent,
                      size: 24,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isDownloaded)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.offline_pin, size: 15, color: AppTheme.primaryAccent),
                        ),
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isPlaying ? AppTheme.primaryAccent : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${song.artist} • ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatDuration(song.duration),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                song.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: song.isFavorite ? AppTheme.primaryAccent : AppTheme.textMuted,
                size: 20,
              ),
              onPressed: () async {
                await playerService.toggleFavorite(song);
                ref.invalidate(songsProvider);
                ref.invalidate(favoritesProvider);
                ref.invalidate(playlistsProvider);
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
              color: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                if (value == 'play_next') {
                  await playerService.playNext(song);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playing next: ${song.title}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else if (value == 'add_queue') {
                  await playerService.addToQueue(song);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to queue: ${song.title}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else if (value == 'add_playlist') {
                  showAddToPlaylistBottomSheet(context, ref, song);
                } else if (value == 'download') {
                  if (isDownloaded) {
                    await downloadService.removeDownload(song.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from downloads')),
                      );
                    }
                  } else {
                    await downloadService.downloadSong(song);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloaded: ${song.title}')),
                      );
                    }
                  }
                } else if (value == 'song_info') {
                  SongInfoScreen.show(context, song);
                } else if (value == 'stats') {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.surfaceColor,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => StatsForNerdsModal(song: song),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Play Next', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Add to Queue', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Add to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(
                        isDownloaded ? Icons.delete_outline : Icons.download_outlined,
                        color: isDownloaded ? Colors.redAccent : AppTheme.primaryAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDownloaded ? 'Remove Download' : 'Download Song',
                        style: TextStyle(color: isDownloaded ? Colors.redAccent : AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'song_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 12),
                      Text('Song Info', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: Colors.cyanAccent, size: 20),
                      SizedBox(width: 12),
                      Text('Stats for Nerds', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
