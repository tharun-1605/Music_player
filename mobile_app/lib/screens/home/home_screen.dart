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

  String _getGreeting(String userName) {
    final hour = DateTime.now().hour;
    final name = userName.trim().isNotEmpty ? userName.trim() : 'Dharaneesh';

    if (hour >= 4 && hour < 12) return 'GOOD MORNING, ${name.toUpperCase()} 👋';
    if (hour >= 12 && hour < 17) return 'GOOD AFTERNOON, ${name.toUpperCase()} 👋';
    if (hour >= 17 && hour < 22) return 'GOOD EVENING, ${name.toUpperCase()} 👋';
    return 'GOOD NIGHT, ${name.toUpperCase()} 🌙';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final artistsAsync = ref.watch(artistsProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final playerService = ref.watch(audioPlayerServiceProvider);
    final userName = ref.watch(userNameProvider);
    final avatarIndex = ref.watch(userAvatarIndexProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,

      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),

        child: Stack(
          children: [
            // ==================================================
            // BLUE ATMOSPHERIC LIGHT
            // ==================================================

            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.blueGlow,
                  ),
                ),
              ),
            ),

            // ==================================================
            // SECONDARY INDIGO ATMOSPHERE
            // ==================================================

            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.violetGlow,
                  ),
                ),
              ),
            ),

            // ==================================================
            // MAIN CONTENT
            // ==================================================

            SafeArea(
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
                  physics: const AlwaysScrollableScrollPhysics(),

                  slivers: [
                    // ==================================================
                    // AUDIOPHILIA HEADER
                    // ==================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        10,
                      ),

                      sliver: SliverToBoxAdapter(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,

                          children: [
                            const AudiophiliaLogo(),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,

                                children: [
                                  const Text(
                                    'AUDIOPHILIA',
                                    style: AppTheme.dotHeading,
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    _getGreeting(userName),
                                    style:
                                        AppTheme.monoBody.copyWith(
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              child: Tooltip(
                                message: 'Profile & Settings',
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primaryAccent,
                                  child: Icon(
                                    kAvatarIcons[avatarIndex % kAvatarIcons.length],
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),


                    // ==================================================
                    // NOTHING DIVIDER
                    // ==================================================

                    const SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16),
                        child: NothingDivider(),
                      ),
                    ),

                    // ==================================================
                    // SERVER STATUS
                    // ==================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        8,
                      ),

                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor
                                .withValues(alpha: 0.82),

                            border: Border.all(
                              color: AppTheme.borderColor,
                            ),

                            borderRadius:
                                BorderRadius.circular(4),
                          ),

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.graphic_eq_outlined,
                                    color:
                                        AppTheme.primaryAccent,
                                    size: 18,
                                  ),

                                  const SizedBox(width: 8),

                                  Text(
                                    'LAN // LOSSLESS STREAM',
                                    style:
                                        AppTheme.monoHeading
                                            .copyWith(
                                      color:
                                          AppTheme.primaryAccent,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 9),

                              songsAsync.when(
                                data: (songs) => Text(
                                  '${songs.length.toString().padLeft(3, '0')} TRACKS'
                                  '   //   FLAC / M4A / OPUS / WAV',

                                  style:
                                      AppTheme.monoBody.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),

                                loading: () => Text(
                                  'CONNECTING TO MUSIC SERVER...',
                                  style: AppTheme.monoBody.copyWith(
                                    fontSize: 10,
                                  ),
                                ),

                                error: (_, __) => Text(
                                  'SERVER OFFLINE // CHECK WI-FI',

                                  style:
                                      AppTheme.monoBody.copyWith(
                                    color:
                                        AppTheme.primaryAccent,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // ARTISTS
                    // ==================================================

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          10,
                        ),

                        child: Text(
                          'ARTISTS // DISCOGRAPHIES',
                          style: AppTheme.dotHeading.copyWith(
                            fontSize: 14,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 145,

                        child: artistsAsync.when(
                          data: (artists) =>
                              ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),

                            scrollDirection:
                                Axis.horizontal,

                            itemCount: artists.length,

                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),

                            itemBuilder:
                                (context, index) {
                              final artist =
                                  artists[index];

                              return SizedBox(
                                width: 110,

                                child: ArtistCard(
                                  artist: artist,

                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ArtistDetailScreen(
                                          artist: artist,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                          loading: () => const Center(
                            child:
                                CircularProgressIndicator(),
                          ),

                          error: (_, __) => Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),

                            child: Text(
                              'ARTIST DATA UNAVAILABLE',
                              style:
                                  AppTheme.monoBody.copyWith(
                                color:
                                    AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // ALBUMS
                    // ==================================================

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          24,
                          16,
                          10,
                        ),

                        child: Text(
                          'ALBUMS // SOUNDTRACKS',
                          style: AppTheme.dotHeading.copyWith(
                            fontSize: 14,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 175,

                        child: albumsAsync.when(
                          data: (albums) =>
                              ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),

                            scrollDirection:
                                Axis.horizontal,

                            itemCount: albums.length,

                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),

                            itemBuilder:
                                (context, index) {
                              final album =
                                  albums[index];

                              return SizedBox(
                                width: 130,

                                child: AlbumCard(
                                  album: album,

                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AlbumDetailScreen(
                                          album: album,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                          loading: () => const Center(
                            child:
                                CircularProgressIndicator(),
                          ),

                          error: (_, __) => Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),

                            child: Text(
                              'ALBUM DATA UNAVAILABLE',
                              style:
                                  AppTheme.monoBody.copyWith(
                                color:
                                    AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // QUICK PICKS
                    // ==================================================

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          24,
                          16,
                          8,
                        ),

                        child: Text(
                          'QUICK PICKS',
                          style: AppTheme.dotHeading.copyWith(
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),

                    songsAsync.when(
                      data: (songs) => SliverList(
                        delegate:
                            SliverChildBuilderDelegate(
                          (context, index) {
                            final song =
                                songs[index];

                            final isPlaying =
                                playerService
                                        .currentSong
                                        ?.id ==
                                    song.id;

                            return SongTile(
                              song: song,
                              isPlaying: isPlaying,

                              onTap: () {
                                playerService.playSongList(
                                  songs,
                                  initialIndex: index,
                                );
                              },
                            );
                          },

                          childCount:
                              songs.take(30).length,
                        ),
                      ),

                      loading:
                          () => const SliverToBoxAdapter(
                        child: Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      ),

                      error: (_, __) =>
                          const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),

                          child: Column(
                            children: [
                              Icon(
                                Icons.wifi_off_outlined,
                                size: 42,
                                color:
                                    AppTheme.primaryAccent,
                              ),

                              SizedBox(height: 12),

                              Text(
                                'MUSIC SERVER DISCONNECTED',

                                style: TextStyle(
                                  fontFamily:
                                      'NType82Mono',
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 12,
                                  color:
                                      AppTheme.textPrimary,
                                  letterSpacing: 1,
                                ),
                              ),

                              SizedBox(height: 8),

                              Text(
                                'CHECK YOUR LOCAL NETWORK CONNECTION.',

                                textAlign:
                                    TextAlign.center,

                                style: TextStyle(
                                  fontFamily:
                                      'NType82Mono',
                                  fontSize: 9,
                                  color:
                                      AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Space above floating dock.
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 110),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// AUDIOPHILIA ANIMATED LOGO
// ================================================================

class AudiophiliaLogo extends StatefulWidget {
  const AudiophiliaLogo({super.key});

  @override
  State<AudiophiliaLogo> createState() =>
      _AudiophiliaLogoState();
}

class _AudiophiliaLogoState
    extends State<AudiophiliaLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,

      builder: (context, child) {
        return Container(
          width: 42,
          height: 42,

          decoration: BoxDecoration(
            color: AppTheme.surfaceColor
                .withValues(alpha: 0.82),

            border: Border.all(
              color: AppTheme.primaryAccent,
              width: 1,
            ),

            borderRadius:
                BorderRadius.circular(4),
          ),

          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,

            crossAxisAlignment:
                CrossAxisAlignment.center,

            children: List.generate(
              5,
              (index) {
                final phase =
                    (_controller.value +
                            index * 0.16) %
                        1.0;

                final wave =
                    Curves.easeInOut.transform(
                  phase,
                );

                final multiplier =
                    index == 2
                        ? 1.25
                        : index.isEven
                            ? 0.8
                            : 1.0;

                final height =
                    (6 + (14 * wave * multiplier))
                        .clamp(5.0, 22.0);

                return Container(
                  width: 2,
                  height: height,

                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 2,
                  ),

                  color:
                      AppTheme.primaryAccent,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// NOTHING STYLE DIVIDER
// ================================================================

class NothingDivider extends StatelessWidget {
  const NothingDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          color: AppTheme.primaryAccent,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.subtleBorder,
          ),
        ),

        const SizedBox(width: 7),

        Text(
          '///',
          style: AppTheme.monoBody.copyWith(
            color: AppTheme.textMuted,
            fontSize: 8,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}