import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../widgets/song_tile.dart';

import '../downloads/downloaded_songs_screen.dart';

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
                try {
                  await api.createPlaylist(name);
                  ref.invalidate(playlistsProvider);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
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
    final downloadService = ref.watch(downloadServiceProvider);
    final downloadedCount = downloadService.downloadedSongs.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Playlist',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: playlistsAsync.when(
        data: (playlists) {
          return RefreshIndicator(
            color: AppTheme.primaryAccent,
            onRefresh: () async => ref.invalidate(playlistsProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: playlists.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.offline_pin, color: AppTheme.primaryAccent, size: 28),
                      ),
                      title: const Text(
                        'Downloaded Music',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryAccent),
                      ),
                      subtitle: Text(
                        'Offline Songs & Playlists • $downloadedCount tracks',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DownloadedSongsScreen()),
                        );
                      },
                    ),
                  );
                }
                final playlist = playlists[index - 1];
                final isFavorites = playlist.isSystem || playlist.name.toLowerCase() == 'favorites';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isFavorites ? AppTheme.primaryAccent.withValues(alpha: 0.1) : AppTheme.cardColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: isFavorites ? Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)) : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isFavorites
                          ? Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight,
                                ),
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                            )
                          : Image.network(
                              '${ApiConfig.apiBaseUrl}/playlists/${playlist.id}/cover',
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.white12,
                                child: const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                              ),
                            ),
                    ),
                    title: Text(
                      playlist.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isFavorites ? AppTheme.primaryAccent : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      isFavorites ? 'Built-in Smart Playlist • ${playlist.songCount} tracks' : '${playlist.songCount} tracks',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    trailing: isFavorites
                        ? const Icon(Icons.lock_outline, size: 18, color: AppTheme.textMuted)
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Delete Playlist',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.cardColor,
                                  title: const Text('Delete Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                                  content: Text('Are you sure you want to delete "${playlist.name}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final api = ref.read(apiServiceProvider);
                                await api.deletePlaylist(playlist.id);
                                ref.invalidate(playlistsProvider);
                              }
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
                  ),
                ),
              );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => RefreshIndicator(
          color: AppTheme.primaryAccent,
          onRefresh: () async => ref.invalidate(playlistsProvider),
          child: ListView(
            children: [
              const SizedBox(height: 200),
              Center(child: Text('Failed to load playlists: $err', style: const TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late Future<Playlist> _playlistFuture;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  void _loadPlaylist() {
    final api = ref.read(apiServiceProvider);
    setState(() {
      _playlistFuture = api.getPlaylistDetails(widget.playlist.id);
    });
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Rename Playlist', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'New playlist name',
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
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final api = ref.read(apiServiceProvider);
                try {
                  await api.renamePlaylist(playlist.id, newName);
                  ref.invalidate(playlistsProvider);
                  _loadPlaylist();
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              }
            },
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiServiceProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);
    final isSystem = widget.playlist.isSystem || widget.playlist.name.toLowerCase() == 'favorites';

    final downloadService = ref.watch(downloadServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download Playlist',
            onPressed: () async {
              final detailed = await _playlistFuture;
              final songs = detailed.songs ?? [];
              if (songs.isNotEmpty) {
                downloadService.downloadPlaylist(songs);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading ${songs.length} tracks from ${widget.playlist.name}...')),
                  );
                }
              }
            },
          ),
          if (!isSystem)
            IconButton(
              icon: Icon(_isReordering ? Icons.done : Icons.import_export, color: _isReordering ? AppTheme.primaryAccent : Colors.white),
              tooltip: _isReordering ? 'Done Reordering' : 'Reorder Songs',
              onPressed: () {
                setState(() {
                  _isReordering = !_isReordering;
                });
              },
            ),
          if (!isSystem)
            PopupMenuButton<String>(
              color: AppTheme.surfaceColor,
              onSelected: (value) async {
                if (value == 'rename') {
                  _showRenameDialog(context, widget.playlist);
                } else if (value == 'add_queue') {
                  final currentQueue = playerService.currentPlaylist;
                  if (currentQueue.isNotEmpty) {
                    final songIds = currentQueue.map((s) => s.id).toList();
                    await api.addBatchToPlaylist(widget.playlist.id, songIds);
                    ref.invalidate(playlistsProvider);
                    _loadPlaylist();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added ${songIds.length} tracks from queue')),
                      );
                    }
                  }
                } else if (value == 'delete') {
                  await api.deletePlaylist(widget.playlist.id);
                  ref.invalidate(playlistsProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename Playlist', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuItem(value: 'add_queue', child: Text('Add Current Queue', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuItem(value: 'delete', child: Text('Delete Playlist', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
        ],
      ),
      body: FutureBuilder<Playlist>(
        future: _playlistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final detailedPlaylist = snapshot.data;
          final songs = detailedPlaylist?.songs ?? [];

          return Column(
            children: [
              // Header Banner with Collage Image
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: isSystem
                          ? Container(
                              width: 90,
                              height: 90,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight,
                                ),
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 48),
                            )
                          : Image.network(
                              '${ApiConfig.apiBaseUrl}/playlists/${widget.playlist.id}/cover',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 90,
                                height: 90,
                                color: Colors.white12,
                                child: const Icon(Icons.queue_music, size: 40, color: AppTheme.primaryAccent),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detailedPlaylist?.name ?? widget.playlist.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSystem ? 'System Smart Playlist • ${songs.length} songs' : '${songs.length} songs',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          if (songs.isNotEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                playerService.playSongList(songs, initialIndex: 0);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              Expanded(
                child: songs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off, size: 48, color: AppTheme.textMuted),
                            SizedBox(height: 8),
                            Text('No songs in playlist', style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : _isReordering && !isSystem
                        ? ReorderableListView.builder(
                            itemCount: songs.length,
                            onReorderItem: (oldIdx, newIdx) async {
                              final mutableSongs = List<Song>.from(songs);
                              final item = mutableSongs.removeAt(oldIdx);
                              mutableSongs.insert(newIdx < oldIdx ? newIdx : newIdx - 1, item);
                              
                              final newSongIds = mutableSongs.map((s) => s.id).toList();
                              await api.reorderPlaylist(widget.playlist.id, newSongIds);
                              _loadPlaylist();
                            },
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              return Container(
                                key: ValueKey('pl_reorder_${song.id}_$index'),
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  leading: ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle, color: AppTheme.textMuted),
                                  ),
                                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              final isPlaying = playerService.currentSong?.id == song.id;
                              return Stack(
                                children: [
                                  SongTile(
                                    song: song,
                                    isPlaying: isPlaying,
                                    onTap: () {
                                      playerService.playSongList(songs, initialIndex: index);
                                    },
                                  ),
                                  if (!isSystem)
                                    Positioned(
                                      right: 48,
                                      top: 8,
                                      bottom: 8,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                          tooltip: 'Remove from playlist',
                                          onPressed: () async {
                                            await api.removeSongFromPlaylist(widget.playlist.id, song.id);
                                            ref.invalidate(playlistsProvider);
                                            _loadPlaylist();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Removed "${song.title}" from playlist')),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
