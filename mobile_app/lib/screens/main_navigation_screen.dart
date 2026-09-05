import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'home/home_screen.dart';
import 'artists/artists_screen.dart';
import 'albums/albums_screen.dart';
import 'songs/songs_screen.dart';
import 'playlists/playlists_screen.dart';
import 'search/search_screen.dart';
import '../widgets/mini_player.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    ArtistsScreen(),
    AlbumsScreen(),
    SongsScreen(),
    PlaylistsScreen(),
    SearchScreen(),
  ];

  final List<IconData> _icons = const [
    Icons.home_outlined,
    Icons.person_outline,
    Icons.album_outlined,
    Icons.music_note_outlined,
    Icons.queue_music_outlined,
    Icons.search_outlined,
  ];

  final List<IconData> _activeIcons = const [
    Icons.home,
    Icons.person,
    Icons.album,
    Icons.music_note,
    Icons.queue_music,
    Icons.search,
  ];

  final List<String> _labels = const [
    'Home',
    'Artists',
    'Albums',
    'Songs',
    'Playlists',
    'Search',
  ];


  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: _currentIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      extendBody: true,

      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLiquidDock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 30,
          sigmaY: 30,
        ),
        child: Container(
          height: 64,

          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 7,
          ),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),

            color: AppTheme.surfaceColor.withValues(
              alpha: 0.42,
            ),

            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              width: 1,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.38,
                ),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.violetAccent.withValues(
                  alpha: 0.08,
                ),
                blurRadius: 25,
              ),
            ],
          ),

          child: Row(
            children: List.generate(
              _labels.length,
              (index) => _buildDockItem(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem(int index) {
    final bool selected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectPage(index),

        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,

            height: 48,

            // Slightly smaller so every tab always has room.
            width: selected ? 78 : 46,

            padding: EdgeInsets.symmetric(
              horizontal: selected ? 8 : 0,
            ),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),

              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryAccent.withValues(
                          alpha: 0.95,
                        ),
                        AppTheme.violetAccent.withValues(
                          alpha: 0.82,
                        ),
                      ],
                    )
                  : null,

              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.20,
                      ),
                      width: 1,
                    )
                  : null,

              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryAccent.withValues(
                          alpha: 0.30,
                        ),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),

            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,

              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.85,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },

              child: selected
                  ? FittedBox(
                      key: ValueKey('active_$index'),

                      // Prevents the icon + label from ever
                      // overflowing its available width.
                      fit: BoxFit.scaleDown,

                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _activeIcons[index],
                            size: 20,
                            color: AppTheme.backgroundColor,
                          ),

                          const SizedBox(width: 5),

                          Text(
                            _labels[index],
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.backgroundColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Icon(
                      _icons[index],
                      key: ValueKey('inactive_$index'),
                      size: 21,
                      color: AppTheme.textSecondary.withValues(
                        alpha: 0.82,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}