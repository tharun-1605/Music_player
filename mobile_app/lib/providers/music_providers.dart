import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/audio_player_service.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/playlist.dart';
import '../models/system_status.dart';
import '../main.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final audioPlayerServiceProvider = ChangeNotifierProvider<AudioPlayerService>((ref) {
  return globalAudioHandler;
});

final systemStatusProvider = FutureProvider<SystemStatus>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getSystemStatus();
});

final songsProvider = FutureProvider<List<Song>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getSongs(limit: 500);
});

final artistsProvider = FutureProvider<List<Artist>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getArtists();
});

final albumsProvider = FutureProvider<List<Album>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAlbums();
});

final favoritesProvider = FutureProvider<List<Song>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getFavorites();
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getPlaylists();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return {'songs': <Song>[], 'artists': <Artist>[], 'albums': <Album>[]};
  }
  final api = ref.watch(apiServiceProvider);
  return await api.search(query);
});
