import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_tile.dart';

class DownloadedSongsScreen extends ConsumerWidget {
  const DownloadedSongsScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadService = ref.watch(downloadServiceProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);
    final downloadedSongs = downloadService.downloadedSongs;
    final storageUsed = downloadService.getTotalStorageUsed();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Music'),
        actions: [
          if (downloadedSongs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: 'Clear All Downloads',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardColor,
                    title: const Text('Clear All Downloads', style: TextStyle(color: AppTheme.textPrimary)),
                    content: Text('Delete all ${downloadedSongs.length} downloaded tracks from device?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete All', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await downloadService.clearAllDownloads();
                }
              },
            ),
        ],
      ),
      body: downloadedSongs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.offline_pin_outlined, size: 72, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'No Downloaded Music',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Download songs or playlists to listen offline without LAN',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.offline_pin, color: AppTheme.primaryAccent, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Library',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${downloadedSongs.length} tracks • ${_formatBytes(storageUsed)} stored',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          playerService.playSongList(downloadedSongs, initialIndex: 0);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                Expanded(
                  child: ListView.builder(
                    itemCount: downloadedSongs.length,
                    itemBuilder: (context, index) {
                      final song = downloadedSongs[index];
                      final isPlaying = playerService.currentSong?.id == song.id;
                      return SongTile(
                        song: song,
                        isPlaying: isPlaying,
                        onTap: () {
                          playerService.playSongList(downloadedSongs, initialIndex: index);
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
