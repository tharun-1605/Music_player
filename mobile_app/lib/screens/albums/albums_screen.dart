import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/album.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/album_card.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'artist', 'songs', 'year'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Album> _filterAndSortAlbums(List<Album> rawAlbums) {
    final query = _searchQuery.trim().toLowerCase();
    var filtered = rawAlbums.where((album) {
      if (query.isEmpty) return true;
      return album.title.toLowerCase().contains(query) ||
          album.artist.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'artist') {
        final cmp = a.artist.compareTo(b.artist);
        return cmp != 0 ? cmp : a.title.compareTo(b.title);
      } else if (_sortBy == 'songs') {
        final cmp = b.songCount.compareTo(a.songCount);
        return cmp != 0 ? cmp : a.title.compareTo(b.title);
      } else if (_sortBy == 'year') {
        final yearA = a.year ?? 0;
        final yearB = b.year ?? 0;
        final cmp = yearB.compareTo(yearA);
        return cmp != 0 ? cmp : a.title.compareTo(b.title);
      } else {
        return a.title.compareTo(b.title);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(albumsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Albums',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18, color: _sortBy == 'name' ? AppTheme.primaryAccent : Colors.white70),
                    const SizedBox(width: 8),
                    Text('Sort by Name (A-Z)', style: TextStyle(color: _sortBy == 'name' ? AppTheme.primaryAccent : Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'artist',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: _sortBy == 'artist' ? AppTheme.primaryAccent : Colors.white70),
                    const SizedBox(width: 8),
                    Text('Sort by Artist', style: TextStyle(color: _sortBy == 'artist' ? AppTheme.primaryAccent : Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'songs',
                child: Row(
                  children: [
                    Icon(Icons.music_note_outlined, size: 18, color: _sortBy == 'songs' ? AppTheme.primaryAccent : Colors.white70),
                    const SizedBox(width: 8),
                    Text('Sort by Track Count', style: TextStyle(color: _sortBy == 'songs' ? AppTheme.primaryAccent : Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'year',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: _sortBy == 'year' ? AppTheme.primaryAccent : Colors.white70),
                    const SizedBox(width: 8),
                    Text('Sort by Release Year', style: TextStyle(color: _sortBy == 'year' ? AppTheme.primaryAccent : Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: albumsAsync.when(
        data: (rawAlbums) {
          final albums = _filterAndSortAlbums(rawAlbums);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search movie albums or artists...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryAccent, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.primaryAccent),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${albums.length} ${_searchQuery.isNotEmpty ? "matches" : "movie albums"}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _sortBy == 'artist'
                            ? 'By Artist'
                            : _sortBy == 'songs'
                                ? 'By Songs'
                                : _sortBy == 'year'
                                    ? 'By Year'
                                    : 'A-Z',
                        style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primaryAccent,
                  onRefresh: () async => ref.invalidate(albumsProvider),
                  child: albums.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 150),
                            Center(
                              child: Text(
                                _searchQuery.isNotEmpty ? 'No albums match "$_searchQuery"' : 'No albums found',
                                style: const TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: albums.length,
                          itemBuilder: (context, index) {
                            final album = albums[index];
                            return AlbumCard(
                              album: album,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(album: album),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },

        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Failed to load albums: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}

