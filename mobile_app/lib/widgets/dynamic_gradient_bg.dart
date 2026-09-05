import 'dart:math';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../config/api_config.dart';

class DynamicGradientBg extends StatefulWidget {
  final int? songId;
  final Widget child;

  const DynamicGradientBg({
    super.key,
    required this.songId,
    required this.child,
  });

  @override
  State<DynamicGradientBg> createState() => _DynamicGradientBgState();
}

class _DynamicGradientBgState extends State<DynamicGradientBg> with TickerProviderStateMixin {
  static final Map<int, List<Color>> _paletteCache = {};

  late AnimationController _transitionController;
  late AnimationController _ambientController;
  
  List<Color> _oldPalette = [
    const Color(0xFF121212),
    const Color(0xFF1E1E2E),
    const Color(0xFF0F0F1A),
  ];
  List<Color> _currentPalette = [
    const Color(0xFF121212),
    const Color(0xFF1E1E2E),
    const Color(0xFF0F0F1A),
  ];

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    if (widget.songId != null) {
      _loadPaletteForSong(widget.songId!);
    }
  }

  @override
  void didUpdateWidget(DynamicGradientBg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songId != oldWidget.songId && widget.songId != null) {
      _loadPaletteForSong(widget.songId!);
    }
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _loadPaletteForSong(int songId) async {
    if (_paletteCache.containsKey(songId)) {
      _updatePalette(_paletteCache[songId]!);
      return;
    }

    try {
      final imageUrl = ApiConfig.getCoverUrl(songId);
      final imageProvider = NetworkImage(imageUrl);
      final paletteGen = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 16,
        timeout: const Duration(seconds: 2),
      );

      final colors = _extractRichColors(paletteGen);
      _paletteCache[songId] = colors;

      if (mounted && widget.songId == songId) {
        _updatePalette(colors);
      }
    } catch (_) {
      final fallback = _defaultFallbackPalette();
      _paletteCache[songId] = fallback;
      if (mounted && widget.songId == songId) {
        _updatePalette(fallback);
      }
    }
  }

  List<Color> _extractRichColors(PaletteGenerator pg) {
    final rawColors = <Color>[];

    if (pg.vibrantColor != null) rawColors.add(pg.vibrantColor!.color);
    if (pg.dominantColor != null) rawColors.add(pg.dominantColor!.color);
    if (pg.lightVibrantColor != null) rawColors.add(pg.lightVibrantColor!.color);
    if (pg.darkVibrantColor != null) rawColors.add(pg.darkVibrantColor!.color);
    if (pg.mutedColor != null) rawColors.add(pg.mutedColor!.color);
    if (pg.darkMutedColor != null) rawColors.add(pg.darkMutedColor!.color);

    // Sanitize muddy / brown / gray colors by boosting saturation & tuning HSL
    final cleanColors = rawColors.map(_sanitizeColor).toList();

    if (cleanColors.isEmpty) {
      return _defaultFallbackPalette();
    } else if (cleanColors.length == 1) {
      final c = cleanColors.first;
      final hsl = HSLColor.fromColor(c);
      final c2 = hsl.withHue((hsl.hue + 45) % 360).withLightness((hsl.lightness * 0.7).clamp(0.15, 0.45)).toColor();
      final c3 = hsl.withHue((hsl.hue + 90) % 360).withLightness(0.1).toColor();
      return [c, c2, c3];
    } else if (cleanColors.length == 2) {
      final c1 = cleanColors[0];
      final c2 = cleanColors[1];
      final hsl = HSLColor.fromColor(c1);
      final c3 = hsl.withLightness(0.08).toColor();
      return [c1, c2, c3];
    } else {
      return cleanColors.take(3).toList();
    }
  }

  Color _sanitizeColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    // If color is too desaturated (gray/muddy), boost saturation
    double sat = hsl.saturation;
    double light = hsl.lightness;

    if (sat < 0.25) {
      sat = 0.45; // boost saturation
    }

    // Keep lightness in deep aesthetic range (0.15 to 0.45) for dark mode player background
    light = light.clamp(0.15, 0.45);

    return hsl.withSaturation(sat).withLightness(light).toColor();
  }

  List<Color> _defaultFallbackPalette() {
    return const [
      Color(0xFF1DB954), // Spotify Green accent
      Color(0xFF191414), // Dark base
      Color(0xFF0F0F1A),
    ];
  }

  void _updatePalette(List<Color> newPalette) {
    setState(() {
      _oldPalette = List.from(_currentPalette);
      _currentPalette = newPalette;
    });
    _transitionController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_transitionController, _ambientController]),
      builder: (context, child) {
        final t = _transitionController.value;
        final ambient = _ambientController.value;

        // Interpolate colors between old and current palette
        final c1 = Color.lerp(_oldPalette[0], _currentPalette[0], t)!;
        final c2 = Color.lerp(_oldPalette[1], _currentPalette[1], t)!;
        final c3 = Color.lerp(_oldPalette.length > 2 ? _oldPalette[2] : _oldPalette[1], _currentPalette.length > 2 ? _currentPalette[2] : _currentPalette[1], t)!;

        // Ambient movement offsets
        final dx = sin(ambient * 2 * pi) * 0.3;
        final dy = cos(ambient * 2 * pi) * 0.3;

        return Stack(
          children: [
            // Dynamic Mesh Animated Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.8 + dx, -1.0 + dy),
                  end: Alignment(0.8 - dx, 1.0 - dy),
                  colors: [c1, c2, c3],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Radial Glow overlay for extra depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0 + dx * 0.5, -0.4 + dy * 0.5),
                    radius: 1.2,
                    colors: [
                      c1.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Dark Contrast Overlay to guarantee text legibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Content Child
            widget.child,
          ],
        );
      },
    );
  }
}
