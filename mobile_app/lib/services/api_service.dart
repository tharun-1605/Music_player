import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/playlist.dart';
import '../models/system_status.dart';

class ConnectionTestResult {
  final bool isConnected;
  final int latencyMs;
  final String message;

  ConnectionTestResult({
    required this.isConnected,
    required this.latencyMs,
    required this.message,
  });
}

class ApiService {
  final http.Client _client = http.Client();

  Future<ConnectionTestResult> testConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode == 200) {
        return ConnectionTestResult(
          isConnected: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Connected to LAN Music Server',
        );
      } else {
        return ConnectionTestResult(
          isConnected: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Server returned HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        isConnected: false,
        latencyMs: 0,
        message: 'Could not connect. Check IP & Wi-Fi.',
      );
    }
  }

  Future<SystemStatus> getSystemStatus() async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/system/status'));
    if (res.statusCode == 200) {
      return SystemStatus.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch system status');
  }

  Future<bool> triggerScan() async {
    final res = await _client.post(Uri.parse('${ApiConfig.apiBaseUrl}/library/scan'));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['started'] as bool? ?? false;
    }
    return false;
  }

  Future<List<Song>> getSongs({
    int page = 1,
    int limit = 100,
    String? artist,
    String? album,
    String? genre,
    String sort = 'title',
    String order = 'asc',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
      'order': order,
    };
    if (artist != null && artist.isNotEmpty) queryParams['artist'] = artist;
    if (album != null && album.isNotEmpty) queryParams['album'] = album;
    if (genre != null && genre.isNotEmpty) queryParams['genre'] = genre;

    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/songs').replace(queryParameters: queryParams);
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List songsJson = body['songs'] ?? [];
      return songsJson.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch songs');
  }

  Future<List<Artist>> getArtists() async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/artists'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((a) => Artist.fromJson(a as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch artists');
  }

  Future<List<Song>> getArtistSongs(int artistId) async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/artists/$artistId/songs'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch artist songs');
  }

  Future<List<Album>> getArtistAlbums(int artistId) async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/artists/$artistId/albums'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((a) => Album.fromJson(a as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch artist albums');
  }

  Future<List<Album>> getAlbums() async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/albums'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((a) => Album.fromJson(a as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch albums');
  }

  Future<List<Song>> getAlbumSongs(int albumId) async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/albums/$albumId/songs'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch album songs');
  }

  Future<Map<String, dynamic>> search(String query) async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/search').replace(queryParameters: {'q': query});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List songsJson = body['songs'] ?? [];
      final List artistsJson = body['artists'] ?? [];
      final List albumsJson = body['albums'] ?? [];

      return {
        'songs': songsJson.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList(),
        'artists': artistsJson.map((a) => Artist.fromJson(a as Map<String, dynamic>)).toList(),
        'albums': albumsJson.map((alb) => Album.fromJson(alb as Map<String, dynamic>)).toList(),
      };
    }
    throw Exception('Failed to search');
  }

  Future<List<Song>> getFavorites() async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/favorites'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch favorites');
  }

  Future<bool> addFavorite(int songId) async {
    final res = await _client.post(Uri.parse('${ApiConfig.apiBaseUrl}/favorites/$songId'));
    return res.statusCode == 201 || res.statusCode == 200;
  }

  Future<bool> removeFavorite(int songId) async {
    final res = await _client.delete(Uri.parse('${ApiConfig.apiBaseUrl}/favorites/$songId'));
    return res.statusCode == 200;
  }

  Future<List<Playlist>> getPlaylists() async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/playlists'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch playlists');
  }

  Future<Playlist> createPlaylist(String name) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.apiBaseUrl}/playlists'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode == 201) {
      return Playlist.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create playlist');
  }

  Future<Playlist> getPlaylistDetails(int playlistId) async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/playlists/$playlistId'));
    if (res.statusCode == 200) {
      return Playlist.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch playlist details');
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await _client.post(Uri.parse('${ApiConfig.apiBaseUrl}/playlists/$playlistId/songs/$songId'));
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await _client.delete(Uri.parse('${ApiConfig.apiBaseUrl}/playlists/$playlistId/songs/$songId'));
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _client.delete(Uri.parse('${ApiConfig.apiBaseUrl}/playlists/$playlistId'));
  }

  Future<void> recordPlayHistory(int songId) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.apiBaseUrl}/history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'song_id': songId}),
      );
    } catch (_) {}
  }

  Future<List<Song>> getPlayHistory() async {
    final res = await _client.get(Uri.parse('${ApiConfig.apiBaseUrl}/history'));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
