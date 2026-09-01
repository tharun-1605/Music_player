import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/album.dart';
import '../../models/song.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artwork.dart';
import '../../widgets/song_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiServiceProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(album.title),
      ),
      body: FutureBuilder<List<Song>>(
        future: api.getAlbumSongs(album.id),
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
                    ArtworkImage(songId: album.id, isAlbum: true, size: 180, borderRadius: 20),
                    const SizedBox(height: 16),
                    Text(
                      album.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${album.artist} ${album.year != null ? "• ${album.year}" : ""}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Shuffle'),
                          onPressed: () {
                            if (songs.isNotEmpty) {
                              final shuffled = List<Song>.from(songs)..shuffle();
                              playerService.playSongList(shuffled, initialIndex: 0);
                            }
                          },
                        ),
                      ],
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
