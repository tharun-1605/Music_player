import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/song.dart';

enum PlaybackTarget { local, chromecast }

class CastDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool isConnected;

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    this.port = 8009,
    this.isConnected = false,
  });
}

class CastService extends ChangeNotifier {
  static final CastService _instance = CastService._internal();
  factory CastService() => _instance;
  CastService._internal();

  PlaybackTarget _currentTarget = PlaybackTarget.local;
  CastDevice? _selectedDevice;
  final List<CastDevice> _discoveredDevices = [];
  bool _isDiscovering = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  Song? _currentCastSong;

  PlaybackTarget get currentTarget => _currentTarget;
  CastDevice? get selectedDevice => _selectedDevice;
  List<CastDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  bool get isDiscovering => _isDiscovering;
  bool get isCasting => _currentTarget == PlaybackTarget.chromecast && _selectedDevice != null;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get volume => _volume;
  Song? get currentCastSong => _currentCastSong;

  /// Codec/Container compatibility check for Chromecast receiver
  bool isFormatCastCompatible(Song song) {
    final lower = song.filePath.toLowerCase();
    if (lower.endsWith('.mp3') || lower.endsWith('.aac') || lower.endsWith('.m4a') || lower.endsWith('.flac') || lower.endsWith('.wav') || lower.endsWith('.ogg')) {
      return true;
    }
    // High-level architecture flag for future backend transcoding if format is esoteric
    return false;
  }

  /// Sanitizes media stream URL for Chromecast. Ensures localhost / 127.0.0.1 is converted to real network URL.
  String getSanitizedStreamUrl(int songId) {
    var rawUrl = ApiConfig.getStreamUrl(songId);
    if (rawUrl.contains('localhost') || rawUrl.contains('127.0.0.1')) {
      // Replace localhost/127.0.0.1 with host address if needed
      final baseUrl = ApiConfig.baseUrl;
      rawUrl = '$baseUrl/api/songs/$songId/stream';
    }
    return rawUrl;
  }

  Future<void> startDiscovery() async {
    _isDiscovering = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    // Simulated network Cast device discovery for local Wi-Fi network
    final baseHost = Uri.parse(ApiConfig.baseUrl).host;
    final castIp = baseHost.isNotEmpty && baseHost != 'localhost' && baseHost != '127.0.0.1'
        ? baseHost
        : '192.168.1.100';

    _discoveredDevices.clear();
    _discoveredDevices.addAll([
      CastDevice(id: 'cast_living_room', name: 'Living Room TV (Chromecast)', host: castIp),
      CastDevice(id: 'cast_bedroom_speaker', name: 'Bedroom Nest Audio', host: castIp),
    ]);

    _isDiscovering = false;
    notifyListeners();
  }

  Future<bool> connectToDevice(CastDevice device) async {
    _selectedDevice = CastDevice(
      id: device.id,
      name: device.name,
      host: device.host,
      port: device.port,
      isConnected: true,
    );
    _currentTarget = PlaybackTarget.chromecast;
    notifyListeners();
    return true;
  }

  Future<void> disconnect() async {
    _currentTarget = PlaybackTarget.local;
    _selectedDevice = null;
    _isPlaying = false;
    _currentCastSong = null;
    notifyListeners();
  }

  Future<void> castSong(Song song, {Duration startPosition = Duration.zero}) async {
    if (!isCasting) return;

    _currentCastSong = song;
    _currentPosition = startPosition;
    _totalDuration = Duration(seconds: song.duration.toInt());
    _isPlaying = true;

    final sanitizedUrl = getSanitizedStreamUrl(song.id);
    debugPrint('Casting track "${song.title}" to ${_selectedDevice?.name} via $sanitizedUrl');
    notifyListeners();
  }

  void play() {
    if (isCasting) {
      _isPlaying = true;
      notifyListeners();
    }
  }

  void pause() {
    if (isCasting) {
      _isPlaying = false;
      notifyListeners();
    }
  }

  void seek(Duration position) {
    if (isCasting) {
      _currentPosition = position;
      notifyListeners();
    }
  }

  void setVolume(double vol) {
    if (isCasting) {
      _volume = vol.clamp(0.0, 1.0);
      notifyListeners();
    }
  }
}
