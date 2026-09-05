import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'equalizer_service.dart';
import '../services/download_service.dart';

class AudioPlayerService extends BaseAudioHandler with ChangeNotifier, QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource _playlistSource = ConcatenatingAudioSource(children: []);

  List<Song> _playlist = [];
  int _currentIndex = -1;

  static const String _keyQueue = 'player_queue_v1';
  static const String _keyCurrentIndex = 'player_current_index_v1';
  static const String _keyShuffle = 'player_shuffle_v1';
  static const String _keyRepeat = 'player_repeat_v1';

  AudioPlayerService() {
    _initPlayerListeners();
    _initEqualizerListener();
  }

  void _initEqualizerListener() {
    EqualizerService().addListener(_applyEqualizerSettings);
    _applyEqualizerSettings();
  }

  void _applyEqualizerSettings() {
    final eq = EqualizerService();
    if (!eq.enabled) {
      _player.setVolume(1.0);
      return;
    }

    final bandGains = eq.bandGains;
    double avgGain = 0.0;
    if (bandGains.isNotEmpty) {
      avgGain = bandGains.reduce((a, b) => a + b) / bandGains.length;
    }

    final totalDb = eq.preamp + avgGain;
    final double volumeMultiplier = pow(10.0, totalDb / 20.0).clamp(0.0, 2.0).toDouble();
    _player.setVolume(volumeMultiplier);
  }

  AudioPlayer get player => _player;
  List<Song> get currentPlaylist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;
  Song? get previousSong => (_currentIndex > 0 && _playlist.isNotEmpty) ? _playlist[_currentIndex - 1] : null;
  Song? get nextSong => (_currentIndex >= 0 && _currentIndex < _playlist.length - 1) ? _playlist[_currentIndex + 1] : null;

  bool get isShuffleEnabled => _player.shuffleModeEnabled;
  LoopMode get loopMode => _player.loopMode;

  AudioSource _createAudioSource(Song song) {
    final downloadService = DownloadService();
    final localPath = downloadService.getDownloadedFilePath(song.id);
    final Uri audioUri = (localPath != null && localPath.isNotEmpty && !localPath.startsWith('web_cached'))
        ? Uri.file(localPath)
        : Uri.parse(ApiConfig.getStreamUrl(song.id));

    return AudioSource.uri(
      audioUri,
      tag: MediaItem(
        id: song.id.toString(),
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: Duration(seconds: song.duration.toInt()),
        artUri: Uri.parse(ApiConfig.getCoverUrl(song.id)),
      ),
    );
  }

  void _initPlayerListeners() {
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ));
        notifyListeners();
      },
      onError: (Object e, StackTrace stackTrace) {
        debugPrint('AudioPlayer error event: $e');
      },
    );

    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _playlist.length) {
        _currentIndex = index;
        final song = _playlist[index];
        _updateMediaItem(song);
        ApiService().recordPlayHistory(song.id);
        notifyListeners();
        _saveQueueState();
      }
    });

    _player.playerStateStream.listen((state) {
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        if (_player.loopMode == LoopMode.off && !_player.hasNext) {
          // End of queue reached in LoopMode.off
        }
      }
    });
  }

  void _updateMediaItem(Song song) {
    mediaItem.add(MediaItem(
      id: song.id.toString(),
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration.toInt()),
      artUri: kIsWeb ? null : Uri.parse(ApiConfig.getCoverUrl(song.id)),
    ));
  }

  Future<void> playSongList(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _playlist = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    
    _playlistSource = ConcatenatingAudioSource(
      children: _playlist.map(_createAudioSource).toList(),
    );

    try {
      await _player.setAudioSource(_playlistSource, initialIndex: _currentIndex);
      await _player.play();
      notifyListeners();
      _saveQueueState();
    } catch (e, st) {
      debugPrint("Error setting audio source: $e\n$st");
    }
  }

  Future<void> shufflePlay(List<Song> songs) async {
    if (songs.isEmpty) return;
    final shuffled = List<Song>.from(songs)..shuffle(Random());
    await playSongList(shuffled, initialIndex: 0);
    await _player.setShuffleModeEnabled(true);
    await _player.shuffle();
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    if (_playlist.isEmpty) {
      await playSongList([song], initialIndex: 0);
      return;
    }
    _playlist.add(song);
    await _playlistSource.add(_createAudioSource(song));
    notifyListeners();
    _saveQueueState();
  }

  Future<void> addListToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_playlist.isEmpty) {
      await playSongList(songs, initialIndex: 0);
      return;
    }
    _playlist.addAll(songs);
    await _playlistSource.addAll(songs.map(_createAudioSource).toList());
    notifyListeners();
    _saveQueueState();
  }

  Future<void> playNext(Song song) async {
    if (_playlist.isEmpty || _currentIndex < 0) {
      await playSongList([song], initialIndex: 0);
      return;
    }
    final insertIndex = _currentIndex + 1;
    _playlist.insert(insertIndex, song);
    await _playlistSource.insert(insertIndex, _createAudioSource(song));
    notifyListeners();
    _saveQueueState();
  }

  Future<void> removeTrackAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    
    _playlist.removeAt(index);
    await _playlistSource.removeAt(index);

    if (_playlist.isEmpty) {
      _currentIndex = -1;
      await _player.stop();
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _playlist.length) {
      _currentIndex = _playlist.length - 1;
    }
    notifyListeners();
    _saveQueueState();
  }

  Future<void> clearQueue() async {
    _playlist.clear();
    await _playlistSource.clear();
    _currentIndex = -1;
    await _player.stop();
    notifyListeners();
    _saveQueueState();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex > _playlist.length) newIndex = _playlist.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final song = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, song);

    await _playlistSource.move(oldIndex, newIndex);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    notifyListeners();
    _saveQueueState();
  }

  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) {
      await _player.play();
    }
    notifyListeners();
  }

  @override
  Future<void> play() async {
    await _player.play();
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_player.shuffleModeEnabled && _playlist.isNotEmpty) {
      final randomIndex = Random().nextInt(_playlist.length);
      await _player.seek(Duration.zero, index: randomIndex);
    } else if (_player.loopMode == LoopMode.all && _playlist.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
    notifyListeners();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_playlist.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    if (enable) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enable);
    notifyListeners();
    _saveQueueState();
  }

  Future<void> toggleRepeat() async {
    final mode = _player.loopMode;
    if (mode == LoopMode.off) {
      await _player.setLoopMode(LoopMode.all);
    } else if (mode == LoopMode.all) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
    _saveQueueState();
  }

  Future<bool> toggleFavorite(Song song) async {
    final isFav = song.isFavorite;
    final newFavState = !isFav;
    final api = ApiService();

    bool success = false;
    if (isFav) {
      success = await api.removeFavorite(song.id);
    } else {
      success = await api.addFavorite(song.id);
    }

    for (int i = 0; i < _playlist.length; i++) {
      if (_playlist[i].id == song.id) {
        _playlist[i] = _playlist[i].copyWith(isFavorite: newFavState);
      }
    }

    notifyListeners();
    _saveQueueState();
    return success;
  }

  Future<void> _saveQueueState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_playlist.map((s) => s.toJson()).toList());
      await prefs.setString(_keyQueue, queueJson);
      await prefs.setInt(_keyCurrentIndex, _currentIndex);
      await prefs.setBool(_keyShuffle, _player.shuffleModeEnabled);
      await prefs.setInt(_keyRepeat, _player.loopMode.index);
    } catch (e) {
      debugPrint('Error saving queue state: $e');
    }
  }

  Future<void> restoreQueueState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = prefs.getString(_keyQueue);
      final index = prefs.getInt(_keyCurrentIndex) ?? -1;
      final shuffle = prefs.getBool(_keyShuffle) ?? false;
      final repeatIndex = prefs.getInt(_keyRepeat) ?? LoopMode.off.index;

      if (queueString != null && queueString.isNotEmpty) {
        final List dynamicList = jsonDecode(queueString);
        final songs = dynamicList.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
        if (songs.isNotEmpty) {
          _playlist = songs;
          _currentIndex = index.clamp(0, _playlist.length - 1);
          _playlistSource = ConcatenatingAudioSource(
            children: _playlist.map(_createAudioSource).toList(),
          );
          await _player.setAudioSource(_playlistSource, initialIndex: _currentIndex);
          await _player.setShuffleModeEnabled(shuffle);
          await _player.setLoopMode(LoopMode.values[repeatIndex.clamp(0, LoopMode.values.length - 1)]);
          if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
            _updateMediaItem(_playlist[_currentIndex]);
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error restoring queue state: $e');
    }
  }
}
