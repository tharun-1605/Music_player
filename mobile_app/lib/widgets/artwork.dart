import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class ArtworkImage extends StatelessWidget {
  final int songId;
  final bool isAlbum;
  final double size;
  final double borderRadius;

  const ArtworkImage({
    super.key,
    required this.songId,
    this.isAlbum = false,
    this.size = 50.0,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = isAlbum
        ? ApiConfig.getAlbumCoverUrl(songId)
        : ApiConfig.getCoverUrl(songId);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        coverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: AppTheme.cardColor,
            child: Icon(
              isAlbum ? Icons.album : Icons.music_note,
              size: size * 0.5,
              color: AppTheme.primaryAccent,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppTheme.cardColor,
            child: Center(
              child: SizedBox(
                width: size * 0.35,
                height: size * 0.35,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryAccent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
