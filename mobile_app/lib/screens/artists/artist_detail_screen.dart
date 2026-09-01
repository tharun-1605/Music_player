import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/artist.dart';
import '../../models/song.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_tile.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiServiceProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name),
      ),
      body: FutureBuilder<List<Song>>(
        future: api.getArtistSongs(artist.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }

          final songs = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, size: 60, color: AppTheme.primaryAccent),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      artist.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${songs.length} Tracks • ${artist.albumCount} Albums',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        if (songs.isNotEmpty) {
                          playerService.playSongList(songs, initialIndex: 0);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tracks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              ...songs.map((song) {
                final isPlaying = playerService.currentSong?.id == song.id;
                return SongTile(
                  song: song,
                  isPlaying: isPlaying,
                  onTap: () {
                    playerService.playSongList(songs, initialIndex: songs.indexOf(song));
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
