import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyBaseUrl = 'server_base_url';
  static const String defaultUrl = 'http://192.168.31.224:8000';

  static String _baseUrl = defaultUrl;

  static String get baseUrl => _baseUrl;

  static String get apiBaseUrl {
    var base = _baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      return base;
    }
    return '$base/api';
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl) ?? defaultUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    var formatted = url.trim();
    while (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('/api')) {
      formatted = formatted.substring(0, formatted.length - 4);
    }
    while (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    _baseUrl = formatted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, _baseUrl);
  }

  static String getStreamUrl(int songId) => '$apiBaseUrl/songs/$songId/stream';
  static String getCoverUrl(int songId) => '$apiBaseUrl/songs/$songId/cover';
  static String getAlbumCoverUrl(int albumId) => '$apiBaseUrl/albums/$albumId/cover';
}
