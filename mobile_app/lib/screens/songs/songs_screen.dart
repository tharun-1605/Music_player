import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_tile.dart';

class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  String _sort = 'title';
  String _order = 'asc';

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Songs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (val) {
              setState(() {
                if (_sort == val) {
                  _order = (_order == 'asc') ? 'desc' : 'asc';
                } else {
                  _sort = val;
                  _order = 'asc';
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'title', child: Text('Sort by Title')),
              const PopupMenuItem(value: 'artist', child: Text('Sort by Artist')),
              const PopupMenuItem(value: 'album', child: Text('Sort by Album')),
              const PopupMenuItem(value: 'duration', child: Text('Sort by Duration')),
            ],
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primaryAccent,
              onRefresh: () async => ref.invalidate(songsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No songs found', style: TextStyle(color: AppTheme.textMuted))),
                ],
              ),
            );
          }

          final sortedSongs = List.of(songs);
          sortedSongs.sort((a, b) {
            int cmp = 0;
            if (_sort == 'artist') {
              cmp = a.artist.compareTo(b.artist);
            } else if (_sort == 'album') {
              cmp = a.album.compareTo(b.album);
            } else if (_sort == 'duration') {
              cmp = a.duration.compareTo(b.duration);
            } else {
              cmp = a.title.compareTo(b.title);
            }
            return _order == 'asc' ? cmp : -cmp;
          });

          return RefreshIndicator(
            color: AppTheme.primaryAccent,
            onRefresh: () async => ref.invalidate(songsProvider),
            child: ListView.builder(
              itemCount: sortedSongs.length,
              itemBuilder: (context, index) {
                final song = sortedSongs[index];
                final isPlaying = playerService.currentSong?.id == song.id;
                return SongTile(
                  song: song,
                  isPlaying: isPlaying,
                  onTap: () {
                    playerService.playSongList(sortedSongs, initialIndex: index);
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => RefreshIndicator(
          color: AppTheme.primaryAccent,
          onRefresh: () async => ref.invalidate(songsProvider),
          child: ListView(
            children: [
              const SizedBox(height: 200),
              Center(child: Text('Failed to load songs: $err', style: const TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      ),

    );
  }
}
