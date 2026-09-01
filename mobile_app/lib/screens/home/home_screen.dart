import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/artist_card.dart';
import '../../widgets/album_card.dart';
import '../artists/artist_detail_screen.dart';
import '../albums/album_detail_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final artistsAsync = ref.watch(artistsProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryAccent,
          backgroundColor: AppTheme.surfaceColor,
          onRefresh: () async {
            ref.invalidate(songsProvider);
            ref.invalidate(artistsProvider);
            ref.invalidate(albumsProvider);
            ref.invalidate(systemStatusProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Spotify Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            onPressed: () {
                              ref.invalidate(songsProvider);
                              ref.invalidate(artistsProvider);
                              ref.invalidate(albumsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Spotify Quick Access Cards Grid (2x3)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryAccent.withValues(alpha: 0.25),
                          AppTheme.surfaceColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.graphic_eq, color: AppTheme.primaryAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'LAN Lossless Streaming',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        songsAsync.when(
                          data: (songs) => Text(
                            '${songs.length} Tracks • FLAC / M4A / Opus / WAV',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          loading: () => const Text('Connecting to music server...', style: TextStyle(color: AppTheme.textMuted)),
                          error: (_, __) => const Text('Server offline. Check Wi-Fi connection.', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Popular Discography Artists
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Artists & Discographies',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 145,
                  child: artistsAsync.when(
                    data: (artists) => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                    error: (err, _) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Failed to load artists', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                ),
              ),

              // Top Albums
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: const Text(
                    'Albums & Soundtracks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: albumsAsync.when(
                    data: (albums) => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: albums.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return SizedBox(
                          width: 130,
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
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                    error: (err, _) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Failed to load albums', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                ),
              ),

              // Songs List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: const Text(
                    'Quick Picks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ),

              // Song List Items
              songsAsync.when(
                data: (songs) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                    childCount: songs.take(30).length,
                  ),
                ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_off, size: 52, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          const Text(
                            'Music Server Disconnected',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ensure your PC is running python3 run.py on Jio AirFiber Wi-Fi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
