import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artwork.dart';
import '../../widgets/queue_sheet.dart';
import '../../widgets/dynamic_gradient_bg.dart';
import '../../widgets/lyrics_view.dart';
import '../../widgets/stats_for_nerds_modal.dart';
import '../../widgets/cast_dialog.dart';
import '../../widgets/add_to_playlist_dialog.dart';
import '../settings/equalizer_screen.dart';
import '../songs/song_info_screen.dart';
import '../albums/album_detail_screen.dart';
import '../artists/artist_detail_screen.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../providers/music_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showLyrics = false;
  bool _showVolume = false;

  // Gesture & Overlay States
  bool _showVolumeOverlay = false;
  double _overlayVolumeLevel = 1.0;
  Timer? _volumeOverlayTimer;

  Offset? _panStartOffset;

  @override
  void dispose() {
    _volumeOverlayTimer?.cancel();
    super.dispose();
  }

  void _triggerVolumeOverlay(double newVol) {
    setState(() {
      _overlayVolumeLevel = newVol.clamp(0.0, 1.0);
      _showVolumeOverlay = true;
    });
    _volumeOverlayTimer?.cancel();
    _volumeOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showVolumeOverlay = false);
    });
  }

  void _openQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const QueueSheet(),
    );
  }

  String _formatTime(Duration duration) {
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final player = playerService.player;
    final currentSong = playerService.currentSong;
    final downloadService = ref.watch(downloadServiceProvider);
    final castService = ref.watch(castServiceProvider);

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(),
        body: const Center(
          child: Text('No track selected', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    final isDownloaded = downloadService.isDownloaded(currentSong.id);
    final isFlac = currentSong.codec.toLowerCase().contains('flac') || currentSong.filePath.toLowerCase().endsWith('.flac');
    final isHiRes = isFlac ||
        currentSong.sampleRate >= 44100 ||
        currentSong.codec.toLowerCase().contains('alac') ||
        currentSong.codec.toLowerCase().contains('wav') ||
        currentSong.codec.toLowerCase().contains('dsd');
    final isDolbyAtmos = currentSong.codec.toLowerCase().contains('atmos') ||
        currentSong.codec.toLowerCase().contains('eac3') ||
        currentSong.codec.toLowerCase().contains('truehd') ||
        currentSong.title.toLowerCase().contains('atmos') ||
        currentSong.album.toLowerCase().contains('atmos');

    return DynamicGradientBg(
      songId: currentSong.id,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            children: [
              const Text(
                'PLAYING FROM ALBUM',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                currentSong.album,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                castService.isCasting ? Icons.cast_connected : Icons.cast,
                color: castService.isCasting ? AppTheme.primaryAccent : Colors.white,
              ),
              tooltip: 'Cast Output',
              onPressed: () => CastDialog.show(context),
            ),
            IconButton(
              icon: Icon(
                _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
                color: _showLyrics ? AppTheme.primaryAccent : Colors.white,
              ),
              tooltip: 'Toggle Lyrics View',
              onPressed: () {
                setState(() {
                  _showLyrics = !_showLyrics;
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                if (value == 'add_queue') {
                  await playerService.addToQueue(currentSong);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to queue: ${currentSong.title}')),
                    );
                  }
                } else if (value == 'play_next') {
                  await playerService.playNext(currentSong);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing next: ${currentSong.title}')),
                    );
                  }
                } else if (value == 'add_playlist') {
                  showAddToPlaylistBottomSheet(context, ref, currentSong);
                } else if (value == 'favorite') {
                  await playerService.toggleFavorite(currentSong);
                  ref.invalidate(songsProvider);
                  ref.invalidate(favoritesProvider);
                  ref.invalidate(playlistsProvider);
                } else if (value == 'download') {
                  if (isDownloaded) {
                    await downloadService.removeDownload(currentSong.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from downloads')),
                      );
                    }
                  } else {
                    await downloadService.downloadSong(currentSong);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloaded: ${currentSong.title}')),
                      );
                    }
                  }
                } else if (value == 'lyrics') {
                  setState(() => _showLyrics = !_showLyrics);
                } else if (value == 'song_info') {
                  SongInfoScreen.show(context, currentSong);
                } else if (value == 'stats') {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.surfaceColor,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => StatsForNerdsModal(song: currentSong),
                  );
                } else if (value == 'eq') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                  );
                } else if (value == 'go_album') {
                  final rawAlbums = ref.read(albumsProvider).value ?? [];
                  final matchedAlbum = rawAlbums.firstWhere(
                    (a) => a.title.toLowerCase() == currentSong.album.toLowerCase(),
                    orElse: () => Album(id: 0, title: currentSong.album, artist: currentSong.artist, songCount: 1),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: matchedAlbum)),
                  );
                } else if (value == 'go_artist') {
                  final rawArtists = ref.read(artistsProvider).value ?? [];
                  final matchedArtist = rawArtists.firstWhere(
                    (a) => a.name.toLowerCase() == currentSong.artist.toLowerCase(),
                    orElse: () => Artist(id: 0, name: currentSong.artist, songCount: 1, albumCount: 1),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: matchedArtist)),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Add to Queue', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Play Next', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Add to Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'favorite',
                  child: Row(
                    children: [
                      Icon(
                        currentSong.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: currentSong.isFavorite ? AppTheme.primaryAccent : AppTheme.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currentSong.isFavorite ? 'Favorite (Added)' : 'Add to Favorites',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(
                        isDownloaded ? Icons.offline_pin : Icons.download_outlined,
                        color: isDownloaded ? AppTheme.primaryAccent : AppTheme.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDownloaded ? 'Downloaded' : 'Download Song',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'lyrics',
                  child: Row(
                    children: [
                      Icon(Icons.lyrics_outlined, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('View Lyrics', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'song_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Song Info', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(Icons.query_stats, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Stats for Nerds', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'eq',
                  child: Row(
                    children: [
                      Icon(Icons.equalizer, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Audio Equalizer', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'go_album',
                  child: Row(
                    children: [
                      Icon(Icons.album_outlined, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Go to Album', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'go_artist',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: AppTheme.textPrimary, size: 20),
                      SizedBox(width: 12),
                      Text('Go to Artist', style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (details) {
                    _panStartOffset = details.globalPosition;
                  },
                  onVerticalDragUpdate: (details) {
                    if (_panStartOffset == null) return;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final screenHeight = MediaQuery.of(context).size.height;
                    final startX = _panStartOffset!.dx;
                    final startY = _panStartOffset!.dy;

                    // 1. Bottom-Left Corner Swipe Up -> Lyrics
                    if (startX < screenWidth * 0.35 && startY > screenHeight * 0.6) {
                      if (details.delta.dy < -15 && !_showLyrics) {
                        setState(() => _showLyrics = true);
                        _panStartOffset = null;
                        return;
                      }
                    }

                    // 2. Bottom-Right Corner Swipe Up -> Queue Sheet
                    if (startX > screenWidth * 0.65 && startY > screenHeight * 0.6) {
                      if (details.delta.dy < -15) {
                        _openQueueSheet();
                        _panStartOffset = null;
                        return;
                      }
                    }

                    // 3. Vertical Drag -> Volume Control
                    final currentVol = player.volume;
                    final deltaVol = -details.delta.dy / 250.0;
                    final newVol = (currentVol + deltaVol).clamp(0.0, 1.0);
                    player.setVolume(newVol);
                    _triggerVolumeOverlay(newVol);
                  },
                  child: Stack(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _showLyrics
                            ? LyricsView(key: ValueKey('lyrics_${currentSong.id}'), song: currentSong)
                            : ArtworkCarousel(
                                key: const ValueKey('artwork_carousel'),
                                playlist: playerService.currentPlaylist,
                                currentIndex: playerService.currentIndex,
                                onSongChanged: (index) {
                                  playerService.skipToQueueIndex(index);
                                },
                              ),
                      ),

                      // Semi-transparent Vertical Volume Bar Overlay
                      if (_showVolumeOverlay)
                        Positioned(
                          left: 20,
                          top: MediaQuery.of(context).size.height * 0.15,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _showVolumeOverlay ? 1.0 : 0.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  width: 52,
                                  height: 190,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24, width: 1),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(
                                        _overlayVolumeLevel == 0.0
                                            ? Icons.volume_off
                                            : (_overlayVolumeLevel < 0.5 ? Icons.volume_down : Icons.volume_up),
                                        color: AppTheme.primaryAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: LinearProgressIndicator(
                                            value: _overlayVolumeLevel,
                                            backgroundColor: Colors.white12,
                                            color: AppTheme.primaryAccent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${(_overlayVolumeLevel * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (castService.isCasting)
                Container(
                  width: double.infinity,
                  color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cast_connected, size: 16, color: AppTheme.primaryAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Playing on ${castService.selectedDevice?.name ?? "Chromecast"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
                      ),
                    ],
                  ),
                ),

              // Title, Artist, & Player Controls Panel
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title & Artist & Favorite
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSong.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentSong.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                   // Quality Badges (Hi-Res / Dolby Atmos / Standard Codec)
                                   Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       if (isHiRes) ...[
                                         Image.asset(
                                           'Asset/HiResLogo.png',
                                           height: 22,
                                           fit: BoxFit.contain,
                                         ),
                                         const SizedBox(width: 8),
                                       ],
                                       if (isDolbyAtmos) ...[
                                         Image.asset(
                                           'Asset/DOLBYATMOS.png',
                                           height: 18,
                                           fit: BoxFit.contain,
                                         ),
                                         const SizedBox(width: 8),
                                       ],
                                       if (!isHiRes && !isDolbyAtmos)
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                           decoration: BoxDecoration(
                                             color: Colors.white.withValues(alpha: 0.08),
                                             borderRadius: BorderRadius.circular(6),
                                           ),
                                           child: Text(
                                             '${currentSong.codec.toUpperCase()} ${currentSong.bitrate > 0 ? "${currentSong.bitrate} KBPS" : ""}',
                                             style: const TextStyle(
                                               fontSize: 10,
                                               fontWeight: FontWeight.bold,
                                               letterSpacing: 0.5,
                                               color: AppTheme.textMuted,
                                             ),
                                           ),
                                         ),
                                     ],
                                   ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                currentSong.isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: currentSong.isFavorite ? AppTheme.primaryAccent : AppTheme.textMuted,
                                size: 28,
                              ),
                              onPressed: () async {
                                await playerService.toggleFavorite(currentSong);
                                ref.invalidate(songsProvider);
                                ref.invalidate(favoritesProvider);
                                ref.invalidate(playlistsProvider);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stream Slider
                        StreamBuilder<Duration>(
                          stream: player.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final totalDuration = Duration(seconds: currentSong.duration.toInt());

                            return Column(
                              children: [
                                SliderTheme(
                                  data: const SliderThemeData(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                    trackHeight: 3,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: position.inSeconds.toDouble().clamp(0.0, totalDuration.inSeconds.toDouble()),
                                    min: 0.0,
                                    max: totalDuration.inSeconds > 0 ? totalDuration.inSeconds.toDouble() : 1.0,
                                    onChanged: (value) {
                                      playerService.seek(Duration(seconds: value.toInt()));
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatTime(position), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                      Text(_formatTime(totalDuration), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Playback Control Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color: player.shuffleModeEnabled ? AppTheme.primaryAccent : AppTheme.textMuted,
                                size: 24,
                              ),
                              onPressed: () => playerService.toggleShuffle(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous, size: 38, color: Colors.white),
                              onPressed: () => playerService.skipToPrevious(),
                            ),
                            // Big Spotify Green Circular Play Button
                            StreamBuilder<PlayerState>(
                              stream: player.playerStateStream,
                              builder: (context, snapshot) {
                                final playing = snapshot.data?.playing ?? false;
                                return Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    iconSize: 36,
                                    icon: Icon(
                                      playing ? Icons.pause : Icons.play_arrow,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      if (playing) {
                                        playerService.pause();
                                      } else {
                                        playerService.play();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next, size: 38, color: Colors.white),
                              onPressed: () => playerService.skipToNext(),
                            ),
                            IconButton(
                              icon: Icon(
                                player.loopMode == LoopMode.one
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                color: player.loopMode != LoopMode.off ? AppTheme.primaryAccent : AppTheme.textMuted,
                                size: 24,
                              ),
                              onPressed: () => playerService.toggleRepeat(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
                                size: 22,
                                color: _showLyrics ? AppTheme.primaryAccent : AppTheme.textMuted,
                              ),
                              tooltip: 'Toggle Lyrics',
                              onPressed: () {
                                setState(() {
                                  _showLyrics = !_showLyrics;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _showVolume ? Icons.volume_up : Icons.volume_down_outlined,
                                size: 22,
                                color: _showVolume ? AppTheme.primaryAccent : AppTheme.textMuted,
                              ),
                              tooltip: 'Volume Control',
                              onPressed: () {
                                setState(() {
                                  _showVolume = !_showVolume;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.queue_music, size: 22, color: AppTheme.textMuted),
                              tooltip: 'Playing Queue',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: AppTheme.surfaceColor,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (_) => const QueueSheet(),
                                );
                              },
                            ),
                          ],
                        ),
                        if (_showVolume) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.volume_mute, size: 16, color: AppTheme.textMuted),
                              Expanded(
                                child: StreamBuilder<double>(
                                  stream: player.volumeStream,
                                  builder: (context, snapshot) {
                                    final vol = snapshot.data ?? player.volume;
                                    return Slider(
                                      activeColor: AppTheme.primaryAccent,
                                      inactiveColor: Colors.white24,
                                      value: vol,
                                      onChanged: (val) {
                                        player.setVolume(val);
                                      },
                                    );
                                  },
                                ),
                              ),
                              const Icon(Icons.volume_up, size: 16, color: AppTheme.textMuted),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtworkCarousel extends StatefulWidget {
  final List<dynamic> playlist;
  final int currentIndex;
  final Function(int) onSongChanged;

  const ArtworkCarousel({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.onSongChanged,
  });

  @override
  State<ArtworkCarousel> createState() => _ArtworkCarouselState();
}

class _ArtworkCarouselState extends State<ArtworkCarousel> {
  late PageController _pageController;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    final initial = (widget.currentIndex.clamp(0, max(0, widget.playlist.length - 1))).toInt();
    _pageController = PageController(
      initialPage: initial,
      viewportFraction: 0.78,
    );
  }

  @override
  void didUpdateWidget(ArtworkCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isUserScrolling && widget.currentIndex != oldWidget.currentIndex && _pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? -1;
      if (currentPage != widget.currentIndex) {
        _pageController.animateToPage(
          widget.currentIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlist.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = min(
          MediaQuery.of(context).size.width * 0.76,
          constraints.maxHeight > 0 ? constraints.maxHeight * 0.85 : 300.0,
        );

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _isUserScrolling = true;
            } else if (notification is ScrollEndNotification) {
              _isUserScrolling = false;
            }
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.playlist.length,
            onPageChanged: (index) {
              if (index != widget.currentIndex) {
                widget.onSongChanged(index);
              }
            },
            itemBuilder: (context, index) {
              final song = widget.playlist[index];

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double scale = 1.0;
                  double opacity = 1.0;
                  if (_pageController.position.haveDimensions) {
                    final pageOffset = (_pageController.page! - index).abs();
                    scale = (1 - (pageOffset * 0.18)).clamp(0.78, 1.0);
                    opacity = (1 - (pageOffset * 0.45)).clamp(0.4, 1.0);
                  } else {
                    scale = index == widget.currentIndex ? 1.0 : 0.82;
                    opacity = index == widget.currentIndex ? 1.0 : 0.55;
                  }

                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6 * opacity),
                                blurRadius: 32 * scale,
                                offset: Offset(0, 14 * scale),
                              ),
                            ],
                          ),
                          child: ArtworkImage(
                            songId: song.id,
                            size: cardSize,
                            borderRadius: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

