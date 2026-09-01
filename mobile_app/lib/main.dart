import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'config/api_config.dart';
import 'services/audio_player_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';

AudioPlayerService globalAudioHandler = AudioPlayerService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();

  try {
    globalAudioHandler = await AudioService.init(
      builder: () => AudioPlayerService(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.lanmusic.mobile_app.channel.audio',
        androidNotificationChannelName: 'LAN Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('AudioService init fallback: $e');
  }

  runApp(const LanMusicApp());
}

class LanMusicApp extends StatelessWidget {
  const LanMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Spotify LAN',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.spotifyTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
