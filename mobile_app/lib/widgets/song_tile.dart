import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../providers/music_providers.dart';
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
    final api = ref.watch(apiServiceProvider);

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
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isPlaying ? AppTheme.primaryAccent : AppTheme.textPrimary,
                    ),
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
                if (song.isFavorite) {
                  await api.removeFavorite(song.id);
                } else {
                  await api.addFavorite(song.id);
                }
                ref.invalidate(songsProvider);
                ref.invalidate(favoritesProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add, color: AppTheme.textMuted, size: 22),
              tooltip: 'Add to Playlist',
              onPressed: () {
                showAddToPlaylistBottomSheet(context, ref, song);
              },
            ),
          ],
        ),
      ),
    );
  }
}

