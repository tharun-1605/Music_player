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

    final double calcIconSize = (size.isFinite && size > 0) ? size * 0.5 : 24.0;
    final double calcProgressSize = (size.isFinite && size > 0) ? size * 0.35 : 18.0;

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
              size: calcIconSize,
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
                width: calcProgressSize,
                height: calcProgressSize,
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
