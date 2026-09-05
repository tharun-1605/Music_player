import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';

class MusicReplayScreen extends ConsumerStatefulWidget {
  const MusicReplayScreen({super.key});

  @override
  ConsumerState<MusicReplayScreen> createState() => _MusicReplayScreenState();
}

class _MusicReplayScreenState extends ConsumerState<MusicReplayScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final GlobalKey _repaintKey = GlobalKey();

  int _currentPage = 0;
  Timer? _timer;
  late AnimationController _progressController;

  static const int totalSlides = 5;
  static const int slideDurationSec = 6;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: slideDurationSec),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSlide();
      }
    });

    _startProgress();
  }

  void _startProgress() {
    _progressController.reset();
    _progressController.forward();
  }

  void _nextSlide() {
    if (_currentPage < totalSlides - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _startProgress();
    } else {
      _progressController.stop();
    }
  }

  void _prevSlide() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _startProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _captureAndShare() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (mounted && pngBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Summary card generated successfully! Ready to share.'),
            backgroundColor: AppTheme.primaryAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export image: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final replayAsync = ref.watch(replayStatsProvider);
    final userName = ref.watch(userNameProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: replayAsync.when(
        data: (stats) {
          final monthMins = (stats['month_minutes'] as num?)?.toDouble() ?? 0.0;
          final totalMins = (stats['total_minutes'] as num?)?.toDouble() ?? 0.0;
          final totalPlays = stats['total_plays'] as int? ?? 0;

          final topSongsList = stats['top_songs'] as List? ?? [];
          final topAlbumsList = stats['top_albums'] as List? ?? [];
          final topArtistsList = stats['top_artists'] as List? ?? [];

          final topTrackName = topSongsList.isNotEmpty
              ? topSongsList[0]['song']['title'] ?? 'No songs yet'
              : 'No songs yet';
          final topTrackArtist = topSongsList.isNotEmpty
              ? topSongsList[0]['song']['artist'] ?? ''
              : '';

          final topArtistName = topArtistsList.isNotEmpty
              ? topArtistsList[0]['artist'] ?? 'No artists yet'
              : 'No artists yet';

          final topAlbumName = topAlbumsList.isNotEmpty
              ? topAlbumsList[0]['album'] ?? 'No albums yet'
              : 'No albums yet';

          return Stack(
            children: [
              // Page View Slideshow
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _startProgress();
                },
                children: [
                  _buildIntroSlide(userName, monthMins, totalMins, totalPlays),
                  _buildTopArtistSlide(topArtistName, topArtistsList),
                  _buildTopTrackSlide(topTrackName, topTrackArtist, topSongsList),
                  _buildTopAlbumSlide(topAlbumName, topAlbumsList),
                  _buildSummarySlide(userName, monthMins, topTrackName, topArtistName, topAlbumName),
                ],
              ),

              // Touch tap navigation areas
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _prevSlide,
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _nextSlide,
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                  ],
                ),
              ),

              // Top Header with Progress Bars & Close Button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: List.generate(totalSlides, (index) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, child) {
                                  double factor = 0.0;
                                  if (index < _currentPage) {
                                    factor = 1.0;
                                  } else if (index == _currentPage) {
                                    factor = _progressController.value;
                                  }
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: factor,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryAccent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.graphic_eq, color: AppTheme.primaryAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "MUSIC REPLAY 2026",
                                style: AppTheme.monoHeading.copyWith(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Scaffold(
          appBar: AppBar(title: const Text('Music Replay')),
          body: Center(child: Text('Error loading stats: $err', style: const TextStyle(color: Colors.redAccent))),
        ),
      ),
    );
  }

  Widget _buildIntroSlide(String name, double monthMins, double totalMins, int totalPlays) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.headphones_outlined, size: 72, color: AppTheme.primaryAccent),
          const SizedBox(height: 24),
          Text(
            "HEY $name! 👋",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "Here is your monthly listening summary.",
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Text(
                  "${monthMins.toInt()}",
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: AppTheme.primaryAccent),
                ),

                const Text("MINUTES LISTENED THIS MONTH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
                const Divider(height: 32, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text("$totalPlays", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text("Total Plays", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    Column(
                      children: [
                        Text("${totalMins.toInt()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text("Lifetime Mins", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtistSlide(String topArtist, List topArtists) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF200122), Color(0xFF6F0000)],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("YOUR TOP ARTIST", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent, letterSpacing: 2)),
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white12,
            child: Icon(Icons.person, size: 70, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            topArtist,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (topArtists.isNotEmpty) ...[
            const Text("Other Frequent Artists:", style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 12),
            ...topArtists.skip(1).take(3).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text("${item['artist']} (${item['play_count']} plays)", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildTopTrackSlide(String topTrack, String artist, List topSongs) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF000428), Color(0xFF004E92)],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("YOUR #1 SONG", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 2)),
          const SizedBox(height: 24),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.3), blurRadius: 30)],
            ),
            child: const Icon(Icons.music_note, size: 70, color: Colors.cyanAccent),
          ),
          const SizedBox(height: 24),
          Text(
            topTrack,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            artist,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopAlbumSlide(String topAlbum, List topAlbums) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("YOUR FAVORITE ALBUM", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 24),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.album, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            topAlbum,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySlide(String name, double mins, String song, String artist, String album) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141E30), Color(0xFF243B55)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF311B92)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.primaryAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryAccent.withValues(alpha: 0.3), blurRadius: 20),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$name's Music Replay",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Icon(Icons.equalizer, color: AppTheme.primaryAccent),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Text("${mins.toInt()} MINUTES LISTENED", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    _buildSummaryItem("Top Song", song, Icons.music_note),
                    const SizedBox(height: 10),
                    _buildSummaryItem("Top Artist", artist, Icons.person),
                    const SizedBox(height: 10),
                    _buildSummaryItem("Top Album", album, Icons.album),
                    const Divider(color: Colors.white24, height: 24),
                    const Text("AUDIOPHILIA // LAN MUSIC PLAYER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse("https://github.com/tharun-1605/Music_player");
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: const Text(
                        "https://github.com/tharun-1605/Music_player",
                        style: TextStyle(fontSize: 9, color: Colors.cyanAccent, decoration: TextDecoration.underline),
                      ),
                    ),
                    const Text("Devs: Tharun & Dharaneesh", style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text("Share Summary Card", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _captureAndShare,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
