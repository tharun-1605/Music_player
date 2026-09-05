import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artist_card.dart';
import 'artist_detail_screen.dart';

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artists & Discographies'),
      ),
      body: artistsAsync.when(
        data: (artists) {
          if (artists.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primaryAccent,
              onRefresh: () async => ref.invalidate(artistsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No artists found', style: TextStyle(color: AppTheme.textMuted))),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryAccent,
            onRefresh: () async => ref.invalidate(artistsProvider),
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return ArtistCard(
                  artist: artist,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(artist: artist),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => RefreshIndicator(
          color: AppTheme.primaryAccent,
          onRefresh: () async => ref.invalidate(artistsProvider),
          child: ListView(
            children: [
              const SizedBox(height: 200),
              Center(child: Text('Failed to load artists: $err', style: const TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      ),

    );
  }
}
