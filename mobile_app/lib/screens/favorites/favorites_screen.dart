import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_tile.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Tracks'),
      ),
      body: favoritesAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('No favorite songs yet', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final isPlaying = playerService.currentSong?.id == song.id;
              return SongTile(
                song: song,
                isPlaying: isPlaying,
                onTap: () {
                  playerService.playSongList(songs, initialIndex: index);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Failed to load favorites: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}
