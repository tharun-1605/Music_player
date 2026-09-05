import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../providers/music_providers.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final playlist = playerService.currentPlaylist;
    final currentIndex = playerService.currentIndex;
    final currentSong = playerService.currentSong;
    final api = ref.watch(apiServiceProvider);

    final remainingIndices = <int>[];
    if (currentIndex >= 0 && currentIndex < playlist.length - 1) {
      for (int i = currentIndex + 1; i < playlist.length; i++) {
        remainingIndices.add(i);
      }
    } else if (currentIndex == -1 && playlist.isNotEmpty) {
      for (int i = 0; i < playlist.length; i++) {
        remainingIndices.add(i);
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Queue Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Queue (${playlist.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (playlist.isNotEmpty)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.playlist_add, color: AppTheme.primaryAccent),
                        tooltip: 'Save Queue as Playlist',
                        onPressed: () {
                          if (playlist.isEmpty) return;
                          final songIds = playlist.map((s) => s.id).toList();
                          showSaveQueueToPlaylistDialog(context, ref, songIds);
                        },
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        icon: const Icon(Icons.clear_all, size: 20),
                        label: const Text('Clear Queue'),
                        onPressed: () {
                          playerService.clearQueue();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: playlist.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_music, size: 64, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Your queue is empty',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add songs to queue to see them here',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Section: NOW PLAYING
                      if (currentSong != null) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 8, top: 4),
                          child: Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppTheme.primaryAccent,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: ArtworkImage(songId: currentSong.id, size: 48, borderRadius: 8),
                            title: Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                            subtitle: Text(
                              '${currentSong.artist} • ${currentSong.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    currentSong.isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: currentSong.isFavorite ? AppTheme.primaryAccent : AppTheme.textMuted,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    if (currentSong.isFavorite) {
                                      await api.removeFavorite(currentSong.id);
                                    } else {
                                      await api.addFavorite(currentSong.id);
                                    }
                                    ref.invalidate(songsProvider);
                                    ref.invalidate(favoritesProvider);
                                  },
                                ),
                                const Icon(Icons.graphic_eq, color: AppTheme.primaryAccent, size: 24),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Section: PLAYING NEXT
                      if (remainingIndices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 8),
                          child: Text(
                            'PLAYING NEXT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: remainingIndices.length,
                          onReorderItem: (oldIdx, newIdx) {
                            final actualOld = remainingIndices[oldIdx];
                            final actualNew = newIdx < remainingIndices.length
                                ? remainingIndices[newIdx]
                                : playlist.length;
                            playerService.reorderQueue(actualOld, actualNew);
                          },
                          itemBuilder: (context, index) {
                            final actualIndex = remainingIndices[index];
                            final song = playlist[actualIndex];

                            return Container(
                              key: ValueKey('queue_song_${song.id}_$actualIndex'),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.drag_handle, color: AppTheme.textMuted, size: 20),
                                      ),
                                    ),
                                    ArtworkImage(songId: song.id, size: 40, borderRadius: 6),
                                  ],
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        song.isFavorite ? Icons.favorite : Icons.favorite_border,
                                        color: song.isFavorite ? AppTheme.primaryAccent : AppTheme.textMuted,
                                        size: 18,
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
                                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                      tooltip: 'Remove from queue',
                                      onPressed: () {
                                        playerService.removeTrackAt(actualIndex);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  playerService.skipToQueueIndex(actualIndex);
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

void showSaveQueueToPlaylistDialog(BuildContext context, WidgetRef ref, List<int> songIds) {
  final controller = TextEditingController(text: 'Queue Playlist');
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Save Queue to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Playlist name',
          hintStyle: TextStyle(color: AppTheme.textMuted),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              final api = ref.read(apiServiceProvider);
              final pl = await api.createPlaylist(name);
              await api.addBatchToPlaylist(pl.id, songIds);
              ref.invalidate(playlistsProvider);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Created playlist "$name" with ${songIds.length} tracks')),
                );
              }
            }
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
