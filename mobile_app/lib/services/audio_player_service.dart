import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../config/api_config.dart';
import '../models/song.dart';

class AudioPlayerService extends BaseAudioHandler with ChangeNotifier, QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  List<Song> _playlist = [];
  int _currentIndex = -1;

  AudioPlayerService() {
    _initPlayerListeners();
  }

  AudioPlayer get player => _player;
  List<Song> get currentPlaylist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;

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
        _updateMediaItem(_playlist[index]);
        notifyListeners();
      }
    });

    _player.playerStateStream.listen((state) {
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
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
      artUri: Uri.parse(ApiConfig.getCoverUrl(song.id)),
    ));
  }

  Future<void> playSongList(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _playlist = List.from(songs);
    _currentIndex = initialIndex;
    notifyListeners();

    try {
      final audioSources = _playlist.map((s) {
        final streamUrl = ApiConfig.getStreamUrl(s.id);
        return AudioSource.uri(
          Uri.parse(streamUrl),
          tag: MediaItem(
            id: s.id.toString(),
            album: s.album,
            title: s.title,
            artist: s.artist,
            duration: Duration(seconds: s.duration.toInt()),
            artUri: Uri.parse(ApiConfig.getCoverUrl(s.id)),
          ),
        );
      }).toList();

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
        initialIndex: initialIndex,
      );
      await _player.play();
      notifyListeners();
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
    }
    notifyListeners();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
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
  }

  void removeTrackAt(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    _playlist.clear();
    _currentIndex = -1;
    _player.stop();
    notifyListeners();
  }
}
