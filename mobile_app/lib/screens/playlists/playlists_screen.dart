import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../models/playlist.dart';
import '../../widgets/song_tile.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Create Playlist', style: TextStyle(color: AppTheme.textPrimary)),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final api = ref.read(apiServiceProvider);
                await api.createPlaylist(name);
                ref.invalidate(playlistsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('No playlists yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
                    onPressed: () => _showCreateDialog(context, ref),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                ),
                title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${playlist.songCount} songs', style: const TextStyle(color: AppTheme.textMuted)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final api = ref.read(apiServiceProvider);
                    await api.deletePlaylist(playlist.id);
                    ref.invalidate(playlistsProvider);
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlist: playlist),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load playlists: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiServiceProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(playlist.name)),
      body: FutureBuilder<Playlist>(
        future: api.getPlaylistDetails(playlist.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final detailedPlaylist = snapshot.data;
          final songs = detailedPlaylist?.songs ?? [];

          if (songs.isEmpty) {
            return const Center(child: Text('No songs in playlist', style: TextStyle(color: AppTheme.textMuted)));
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
      ),
    );
  }
}
