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

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playing Queue (${playlist.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear_all, size: 20, color: Colors.redAccent),
                label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  playerService.clearQueue();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: playlist.isEmpty
                ? const Center(
                    child: Text('Queue is empty', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.builder(
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final isCurrent = index == currentIndex;

                      return ListTile(
                        leading: ArtworkImage(songId: song.id, size: 44, borderRadius: 8),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? AppTheme.primaryAccent : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                          onPressed: () {
                            playerService.removeTrackAt(index);
                          },
                        ),
                        onTap: () {
                          playerService.playSongList(playlist, initialIndex: index);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
