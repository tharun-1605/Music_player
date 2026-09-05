import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/song.dart';

enum DownloadStatus { idle, downloading, completed, failed, paused }

class DownloadTask {
  final Song song;
  double progress;
  DownloadStatus status;
  int downloadedBytes;
  int totalBytes;
  String? localPath;
  String? errorMessage;

  DownloadTask({
    required this.song,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.localPath,
    this.errorMessage,
  });
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal() {
    _loadMetadataFromPrefs();
  }

  static const String _prefsKey = 'downloaded_songs_metadata_v1';
  final Map<int, DownloadTask> _tasks = {};
  final Map<int, String> _downloadedPaths = {};

  List<Song> get downloadedSongs => _tasks.values
      .where((t) => t.status == DownloadStatus.completed)
      .map((t) => t.song)
      .toList();

  bool isDownloaded(int songId) {
    if (_downloadedPaths.containsKey(songId)) {
      final path = _downloadedPaths[songId]!;
      if (kIsWeb || File(path).existsSync()) {
        return true;
      }
    }
    return false;
  }

  String? getDownloadedFilePath(int songId) {
    if (isDownloaded(songId)) {
      return _downloadedPaths[songId];
    }
    return null;
  }

  DownloadTask? getTask(int songId) => _tasks[songId];

  int getTotalStorageUsed() {
    int bytes = 0;
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.completed && task.localPath != null) {
        if (!kIsWeb) {
          final file = File(task.localPath!);
          if (file.existsSync()) {
            bytes += file.lengthSync();
          }
        } else {
          bytes += task.song.fileSize;
        }
      }
    }
    return bytes;
  }

  Future<void> _loadMetadataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List dynamicList = jsonDecode(jsonStr);
        for (final item in dynamicList) {
          final songMap = item['song'] as Map<String, dynamic>;
          final song = Song.fromJson(songMap);
          final path = item['local_path'] as String;

          if (kIsWeb || File(path).existsSync()) {
            _downloadedPaths[song.id] = path;
            _tasks[song.id] = DownloadTask(
              song: song,
              progress: 1.0,
              status: DownloadStatus.completed,
              downloadedBytes: song.fileSize,
              totalBytes: song.fileSize,
              localPath: path,
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading download metadata: $e');
    }
  }

  Future<void> _saveMetadataToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = <Map<String, dynamic>>[];

      for (final task in _tasks.values) {
        if (task.status == DownloadStatus.completed && task.localPath != null) {
          list.add({
            'song': task.song.toJson(),
            'local_path': task.localPath,
          });
        }
      }

      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving download metadata: $e');
    }
  }

  Future<Directory> _getDownloadsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${docsDir.path}/lan_music_downloads');
    if (!downloadsDir.existsSync()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  Future<void> downloadSong(Song song) async {
    if (isDownloaded(song.id)) return;

    final task = DownloadTask(
      song: song,
      status: DownloadStatus.downloading,
      totalBytes: song.fileSize,
    );
    _tasks[song.id] = task;
    notifyListeners();

    try {
      final streamUrl = ApiConfig.getStreamUrl(song.id);
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode}');
      }

      if (kIsWeb) {
        // Web mock download handling
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.localPath = 'web_cached_${song.id}';
        _downloadedPaths[song.id] = task.localPath!;
        await _saveMetadataToPrefs();
        notifyListeners();
        return;
      }

      final dir = await _getDownloadsDirectory();
      final ext = song.filePath.contains('.') ? song.filePath.split('.').last : 'mp3';
      final tmpFile = File('${dir.path}/song_${song.id}.tmp');
      final finalFile = File('${dir.path}/song_${song.id}.$ext');

      final sink = tmpFile.openWrite();
      int downloaded = 0;

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloaded += chunk.length;
          task.downloadedBytes = downloaded;
          if (song.fileSize > 0) {
            task.progress = (downloaded / song.fileSize).clamp(0.0, 1.0);
          } else {
            task.progress = 0.5;
          }
          notifyListeners();
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();

      // Atomic Rename from .tmp to final extension
      if (tmpFile.existsSync()) {
        await tmpFile.rename(finalFile.path);
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.localPath = finalFile.path;
        _downloadedPaths[song.id] = finalFile.path;

        await _saveMetadataToPrefs();
        notifyListeners();
      } else {
        throw Exception('Temporary download file missing');
      }
    } catch (e) {
      debugPrint('Download error for ${song.title}: $e');
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> downloadAlbum(List<Song> songs) async {
    for (final song in songs) {
      await downloadSong(song);
    }
  }

  Future<void> downloadPlaylist(List<Song> songs) async {
    for (final song in songs) {
      await downloadSong(song);
    }
  }

  Future<void> removeDownload(int songId) async {
    final task = _tasks[songId];
    if (task != null && task.localPath != null && !kIsWeb) {
      try {
        final file = File(task.localPath!);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
    }

    _tasks.remove(songId);
    _downloadedPaths.remove(songId);
    await _saveMetadataToPrefs();
    notifyListeners();
  }

  Future<void> clearAllDownloads() async {
    for (final songId in List<int>.from(_downloadedPaths.keys)) {
      await removeDownload(songId);
    }
  }
}
