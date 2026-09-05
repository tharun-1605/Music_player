import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artwork.dart';

class SongInfoScreen extends ConsumerWidget {
  final Song song;

  const SongInfoScreen({
    super.key,
    required this.song,
  });

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SongInfoScreen(song: song),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'N/A';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')} (${seconds.toStringAsFixed(1)}s)';
  }

  /// Sanitizes full server paths to obscure internal filesystem hierarchy
  String _sanitizePath(String rawPath) {
    if (rawPath.isEmpty) return 'N/A';
    final parts = rawPath.replaceAll('\\', '/').split('/');
    if (parts.length > 3) {
      return parts.sublist(parts.length - 3).join('/');
    }
    return rawPath;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadService = ref.watch(downloadServiceProvider);
    final isDownloaded = downloadService.isDownloaded(song.id);
    final localPath = downloadService.getDownloadedFilePath(song.id);
    final lyricsAsync = ref.watch(lyricsProvider(song.id));

    final isFlac = song.codec.toLowerCase().contains('flac') || song.filePath.toLowerCase().endsWith('.flac');
    final bitDepth = isFlac ? '24-bit' : '16-bit';
    final container = song.filePath.contains('.') ? song.filePath.split('.').last.toUpperCase() : song.codec.toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ArtworkImage(songId: song.id, size: 56, borderRadius: 8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${song.artist} • ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 24),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // GENERAL METADATA
                  _buildSectionHeader(Icons.info_outline, 'GENERAL METADATA'),
                  _buildInfoTile('Title', song.title),
                  _buildInfoTile('Artist', song.artist),
                  _buildInfoTile('Album', song.album),
                  if (song.albumArtist != null && song.albumArtist!.isNotEmpty)
                    _buildInfoTile('Album Artist', song.albumArtist!),
                  _buildInfoTile('Track Number', song.trackNumber != null ? '${song.trackNumber}' : 'N/A'),
                  _buildInfoTile('Disc Number', song.discNumber != null ? '${song.discNumber}' : 'N/A'),
                  _buildInfoTile('Release Year', song.year != null ? '${song.year}' : 'N/A'),
                  _buildInfoTile('Genre', song.genre ?? 'N/A'),

                  const SizedBox(height: 20),

                  // AUDIO SPECIFICATIONS
                  _buildSectionHeader(Icons.graphic_eq, 'AUDIO SPECIFICATIONS'),
                  _buildInfoTile('Audio Codec', song.codec.isNotEmpty ? song.codec.toUpperCase() : 'N/A'),
                  _buildInfoTile('Container Format', container),
                  _buildInfoTile('Sample Rate', song.sampleRate > 0 ? '${song.sampleRate} Hz' : 'N/A'),
                  _buildInfoTile('Bit Depth', bitDepth),
                  _buildInfoTile('Bitrate', song.bitrate > 0 ? '${song.bitrate} kbps' : 'N/A'),
                  _buildInfoTile('Channels', '2 Channels (Stereo)'),
                  _buildInfoTile('Duration', _formatDuration(song.duration)),
                  _buildInfoTile('Original File Size', _formatBytes(song.fileSize)),

                  const SizedBox(height: 20),

                  // SERVER & LOCATION
                  _buildSectionHeader(Icons.dns_outlined, 'SERVER & LOCATION'),
                  _buildInfoTile('Server Name', 'LAN Music Server'),
                  _buildInfoTile('Music Track ID', '#${song.id}'),
                  _buildInfoTile('Relative Path', _sanitizePath(song.filePath)),
                  _buildInfoTile('Stream Source', isDownloaded ? 'Offline Cache (Local)' : 'LAN HTTP Stream'),

                  const SizedBox(height: 20),

                  // OFFLINE STORAGE
                  _buildSectionHeader(Icons.sd_storage_outlined, 'OFFLINE STORAGE'),
                  _buildInfoTile('Downloaded Status', isDownloaded ? 'Yes (Cached Offline)' : 'No (Stream Only)'),
                  _buildInfoTile('Local Cached Path', localPath != null ? _sanitizePath(localPath) : 'N/A'),
                  _buildInfoTile('Offline Disk Size', isDownloaded ? _formatBytes(song.fileSize) : 'N/A'),

                  const SizedBox(height: 20),

                  // LYRICS INFORMATION
                  _buildSectionHeader(Icons.lyrics_outlined, 'LYRICS INFORMATION'),
                  lyricsAsync.when(
                    data: (lyrics) {
                      final hasLyrics = lyrics.lyricsSource != 'unavailable' && (lyrics.timedLyrics.isNotEmpty || (lyrics.plainLyrics != null && lyrics.plainLyrics!.isNotEmpty));
                      final isSynced = lyrics.isSynced || lyrics.timedLyrics.isNotEmpty;
                      return Column(
                        children: [
                          _buildInfoTile('Lyrics Available', hasLyrics ? 'Yes' : 'No'),
                          _buildInfoTile('Lyrics Type', isSynced ? 'Timed Synced (.LRC)' : (hasLyrics ? 'Unsynced Plain Text' : 'N/A')),
                          _buildInfoTile('Source / Provider', lyrics.lyricsSource.toUpperCase()),
                        ],
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                    error: (_, __) => _buildInfoTile('Lyrics Status', 'Unavailable'),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
