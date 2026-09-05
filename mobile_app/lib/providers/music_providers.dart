import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/audio_player_service.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/playlist.dart';
import '../models/system_status.dart';
import '../models/lyric.dart';
import '../main.dart';

import '../services/download_service.dart';
import '../services/equalizer_service.dart';
import '../services/cast_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final downloadServiceProvider = ChangeNotifierProvider<DownloadService>((ref) {
  return DownloadService();
});

final equalizerServiceProvider = ChangeNotifierProvider<EqualizerService>((ref) {
  return EqualizerService();
});

final castServiceProvider = ChangeNotifierProvider<CastService>((ref) {
  return CastService();
});

final audioPlayerServiceProvider = ChangeNotifierProvider<AudioPlayerService>((ref) {
  return globalAudioHandler;
});

final lyricsProvider = FutureProvider.family<SongLyrics, int>((ref, songId) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getLyrics(songId);
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

final userNameProvider = StateProvider<String>((ref) => 'Dharaneesh');

final userAvatarIndexProvider = StateProvider<int>((ref) => 0);

final replayStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getReplayStats();
});

final searchResultsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return {'songs': <Song>[], 'artists': <Artist>[], 'albums': <Album>[]};
  }
  final api = ref.watch(apiServiceProvider);
  return await api.search(query);
});

