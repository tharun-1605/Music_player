import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artwork.dart';
import '../../models/song.dart';
import '../player/player_screen.dart';
import '../../widgets/add_to_playlist_dialog.dart';

class MusicReplayScreen extends ConsumerStatefulWidget {
  const MusicReplayScreen({super.key});

  @override
  ConsumerState<MusicReplayScreen> createState() => _MusicReplayScreenState();
}

class _MusicReplayScreenState extends ConsumerState<MusicReplayScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  Future<void> _shareSummary() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (mounted && pngBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Replay summary ready to share!'),
            backgroundColor: AppTheme.primaryAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final replayAsync = ref.watch(replayStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: replayAsync.when(
          data: (stats) => Text(
            stats['month_year'] ?? 'Replay \'26',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          loading: () => const Text('Replay \'26', style: TextStyle(color: Colors.white)),
          error: (_, __) => const Text('Replay \'26', style: TextStyle(color: Colors.white)),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.redAccent, size: 22),
            onPressed: _shareSummary,
          ),
        ],
      ),
      body: replayAsync.when(
        data: (stats) {
          final monthMins = (stats['month_minutes'] as num?)?.toDouble() ?? 0.0;
          final monthName = stats['month_name'] ?? 'this month';
          final topSongsList = stats['top_songs'] as List? ?? [];
          final topArtistsList = stats['top_artists'] as List? ?? [];
          final topAlbumsList = stats['top_albums'] as List? ?? [];

          return RefreshIndicator(
            color: AppTheme.primaryAccent,
            onRefresh: () async => ref.invalidate(replayStatsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: RepaintBoundary(
                key: _repaintKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Apple Music Style Headline with Counter Animation
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        children: [
                          const TextSpan(text: 'You listened for '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: monthMins),
                              duration: const Duration(milliseconds: 1600),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                          TextSpan(text: ' minutes in $monthName.'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Your Top Artists Section
                    if (topArtistsList.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Top Artists',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.white54, size: 24),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: topArtistsList.length,
                          itemBuilder: (context, index) {
                            final artItem = topArtistsList[index];
                            final artistName = artItem['artist'] ?? 'Unknown Artist';
                            final mins = artItem['minutes'] ?? 0;
                            final songId = artItem['song_id'] as int?;

                            return Container(
                              width: 210,
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: AppTheme.cardColor,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (songId != null)
                                      ArtworkImage(songId: songId, borderRadius: 20)
                                    else
                                      Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Icon(Icons.person, size: 80, color: Colors.white24),
                                      ),

                                    // Dark bottom gradient overlay
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.transparent, Colors.black87, Colors.black],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: [0.3, 0.75, 1.0],
                                        ),
                                      ),
                                    ),

                                    // Rank Number at Top Left
                                    Positioned(
                                      top: 12,
                                      left: 16,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 54,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          shadows: const [
                                            Shadow(color: Colors.black, blurRadius: 10),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Artist Name & Minutes at Bottom
                                    Positioned(
                                      bottom: 16,
                                      left: 16,
                                      right: 16,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            artistName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$mins minutes',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],

                    // Your Top Songs Section
                    if (topSongsList.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Top Songs',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.white54, size: 24),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: topSongsList.length,
                        itemBuilder: (context, index) {
                          final item = topSongsList[index];
                          final songJson = item['song'] as Map<String, dynamic>;
                          final song = Song.fromJson(songJson);
                          final playCount = item['play_count'] as int? ?? 1;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: index == 0
                                            ? AppTheme.primaryAccent
                                            : Colors.white70,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ArtworkImage(songId: song.id, size: 48, borderRadius: 8),
                                ],
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                '${song.artist} • $playCount Plays',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                color: AppTheme.surfaceColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) async {
                                  final playerService = ref.read(audioPlayerServiceProvider);
                                  if (val == 'play') {
                                    final songs = topSongsList.map((e) => Song.fromJson(e['song'])).toList();
                                    playerService.playSongList(songs, initialIndex: index);
                                    PlayerScreen.open(context);
                                  } else if (val == 'add_queue') {
                                    playerService.addToQueue(song);
                                  } else if (val == 'add_playlist') {
                                    showAddToPlaylistBottomSheet(context, ref, song);
                                  } else if (val == 'favorite') {
                                    await playerService.toggleFavorite(song);
                                    ref.invalidate(replayStatsProvider);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'play', child: Text('Play Track', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'add_queue', child: Text('Add to Queue', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'add_playlist', child: Text('Add to Playlist', style: TextStyle(color: Colors.white))),
                                  PopupMenuItem(value: 'favorite', child: Text(song.isFavorite ? 'Remove Favorite' : 'Add to Favorites', style: const TextStyle(color: Colors.white))),
                                ],
                              ),
                              onTap: () {
                                final playerService = ref.read(audioPlayerServiceProvider);
                                final songs = topSongsList.map((e) => Song.fromJson(e['song'])).toList();
                                playerService.playSongList(songs, initialIndex: index);
                                PlayerScreen.open(context);
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 36),
                    ],

                    // Your Top Albums Section
                    if (topAlbumsList.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Top Albums',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.white54, size: 24),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: topAlbumsList.length,
                          itemBuilder: (context, index) {
                            final albItem = topAlbumsList[index];
                            final albName = albItem['album'] ?? 'Unknown Album';
                            final cnt = albItem['play_count'] ?? 1;

                            return Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 140,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: const Icon(Icons.album_outlined, size: 54, color: AppTheme.primaryAccent),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    albName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    '$cnt Plays',
                                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryAccent),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(title: const Text('Music Replay')),
          body: Center(
            child: Text('Error loading stats: $err', style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      ),
    );
  }
}
