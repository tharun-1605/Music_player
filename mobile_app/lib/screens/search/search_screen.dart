import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/artist_card.dart';
import '../../widgets/album_card.dart';
import '../artists/artist_detail_screen.dart';
import '../albums/album_detail_screen.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Search songs, artists, albums...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              ref.read(searchQueryProvider.notifier).state = '';
            },
          ),
        ],
      ),
      body: searchResultsAsync.when(
        data: (data) {
          final songs = (data['songs'] ?? []) as List;
          final artists = (data['artists'] ?? []) as List;
          final albums = (data['albums'] ?? []) as List;

          if (songs.isEmpty && artists.isEmpty && albums.isEmpty) {
            return const Center(
              child: Text('Search for songs, discography artists, or albums',
                  style: TextStyle(color: AppTheme.textMuted)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (artists.isNotEmpty) ...[
                const Text('Artists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: artists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      return SizedBox(
                        width: 110,
                        child: ArtistCard(
                          artist: artist,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (albums.isNotEmpty) ...[
                const Text('Albums', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return SizedBox(
                        width: 120,
                        child: AlbumCard(
                          album: album,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (songs.isNotEmpty) ...[
                const Text('Songs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...songs.map((song) {
                  final isPlaying = playerService.currentSong?.id == song.id;
                  return SongTile(
                    song: song,
                    isPlaying: isPlaying,
                    onTap: () {
                      playerService.playSongList(List.from(songs), initialIndex: songs.indexOf(song));
                    },
                  );
                }),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Search error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}
