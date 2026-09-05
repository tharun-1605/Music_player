import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/server_discovery_service.dart';
import '../replay/music_replay_screen.dart';
import 'downloads_settings_screen.dart';
import 'equalizer_screen.dart';

const List<IconData> kAvatarIcons = [
  Icons.person,
  Icons.headphones,
  Icons.music_note,
  Icons.graphic_eq,
  Icons.stars,
  Icons.sentiment_very_satisfied,
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;
  late TextEditingController _nameController;
  ConnectionTestResult? _testResult;
  bool _testing = false;
  bool _discovering = false;
  bool _scanning = false;
  String? _discoveryMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
    _nameController = TextEditingController(text: ref.read(userNameProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _autoDiscoverServer() async {
    setState(() {
      _discovering = true;
      _discoveryMessage = 'Scanning local Wi-Fi network for Music Server...';
    });

    final result = await ServerDiscoveryService.discoverServer();

    if (mounted) {
      setState(() {
        _discovering = false;
        _discoveryMessage = result.message;
        if (result.success && result.discoveredUrl != null) {
          _urlController.text = result.discoveredUrl!;
        }
      });

      if (result.success) {
        _testConnection();
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    await ApiConfig.setBaseUrl(_urlController.text);
    final api = ref.read(apiServiceProvider);
    final result = await api.testConnection();
    setState(() {
      _testResult = result;
      _testing = false;
    });

    if (result.isConnected) {
      ref.invalidate(systemStatusProvider);
      ref.invalidate(songsProvider);
      ref.invalidate(artistsProvider);
      ref.invalidate(albumsProvider);
    }
  }

  Future<void> _triggerScan() async {
    setState(() => _scanning = true);
    final api = ref.read(apiServiceProvider);
    await api.triggerScan();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Library scan initiated on server.')),
      );
    }
    setState(() => _scanning = false);
    ref.invalidate(systemStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final systemStatusAsync = ref.watch(systemStatusProvider);
    final currentAvatarIndex = ref.watch(userAvatarIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==================================================
          // USER PROFILE SECTION
          // ==================================================
          const Text(
            'User Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryAccent,
                        child: Icon(kAvatarIcons[currentAvatarIndex % kAvatarIcons.length], color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Your Name',
                            labelStyle: const TextStyle(color: AppTheme.textMuted),
                            hintText: 'Enter your name (e.g. Dharaneesh)',
                            filled: true,
                            fillColor: AppTheme.cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            ref.read(userNameProvider.notifier).state = val.trim().isEmpty ? 'Dharaneesh' : val.trim();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Avatar Icon:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(kAvatarIcons.length, (idx) {
                      final selected = currentAvatarIndex == idx;
                      return GestureDetector(
                        onTap: () {
                          ref.read(userAvatarIndexProvider.notifier).state = idx;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? AppTheme.primaryAccent : Colors.white10,
                            border: selected ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                          child: Icon(kAvatarIcons[idx], size: 20, color: Colors.white),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // APPLE REPLAY / SPOTIFY WRAPPED BANNER
          // ==================================================
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 42, color: Colors.amberAccent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR MUSIC REPLAY',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Explore your top songs, artists & total minutes listened!',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('View Replay Story', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MusicReplayScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // LAN SERVER CONNECTION
          // ==================================================
          const Text(
            'LAN Server Connection',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Server URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.31.224:8000',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _discovering
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.radar, color: Colors.white),
                          label: const Text('Auto-Discover Server', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _discovering ? null : _autoDiscoverServer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Test'),
                      ),
                    ],
                  ),
                  if (_discoveryMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _discoveryMessage!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testResult!.isConnected
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _testResult!.isConnected ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testResult!.isConnected ? Icons.check_circle : Icons.error,
                            color: _testResult!.isConnected ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _testResult!.isConnected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _testResult!.isConnected ? Colors.green : Colors.red,
                                  ),
                                ),
                                Text(
                                  '${_testResult!.message} (${_testResult!.latencyMs} ms)',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // OFFLINE DOWNLOADS SECTION
          // ==================================================
          const Text(
            'Offline Downloads & Storage',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.surfaceColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryAccent,
                child: Icon(Icons.download_done, color: Colors.white),
              ),
              title: const Text(
                'Downloaded Songs & Cache',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              subtitle: Builder(
                builder: (context) {
                  final downloadService = ref.watch(downloadServiceProvider);
                  final count = downloadService.downloadedSongs.length;
                  final sizeMb = (downloadService.getTotalStorageUsed() / (1024 * 1024)).toStringAsFixed(1);
                  return Text(
                    '$count songs stored ($sizeMb MB)',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  );
                },
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadsSettingsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // EQUALIZER & AUDIO DSP SECTION
          // ==================================================
          const Text(
            'Equalizer & Sound Presets',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.surfaceColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryAccent,
                child: Icon(Icons.equalizer, color: Colors.white),
              ),
              title: const Text(
                '10-Band Equalizer & Presets',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              subtitle: Builder(
                builder: (context) {
                  final eq = ref.watch(equalizerServiceProvider);
                  return Text(
                    eq.enabled ? 'Active Preset: ${eq.currentPresetName}' : 'Equalizer Disabled',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  );
                },
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // MUSIC LIBRARY & STORAGE
          // ==================================================
          const Text(
            'Music Library & HDD Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          systemStatusAsync.when(
            data: (status) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatusRow('External HDD', status.hddConnected ? 'Connected' : 'Disconnected', status.hddConnected),
                    const Divider(color: Colors.white10),
                    _buildStatusRow('Music Path', status.musicPath, status.readable),
                    const Divider(color: Colors.white10),
                    _buildStatusRow('Files on Storage', '${status.totalFiles} files', true),
                    const Divider(color: Colors.white10),
                    _buildStatusRow('Database Library', '${status.totalSongsInDb} songs (${status.totalArtistsInDb} artists, ${status.totalAlbumsInDb} albums)', true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryAccent,
                          side: const BorderSide(color: AppTheme.primaryAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.sync),
                        label: const Text('Rescan Music Library'),
                        onPressed: _scanning ? null : _triggerScan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load status: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // DEVELOPER & PROJECT CREDITS
          // ==================================================
          const Text(
            'Project & Developers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      GithubLogoIcon(size: 22, color: AppTheme.primaryAccent),
                      SizedBox(width: 10),
                      Text('GitHub Repository', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openUrl('https://github.com/tharun-1605/Music_player'),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 14, color: Colors.cyanAccent),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'https://github.com/tharun-1605/Music_player',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.cyanAccent,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.cyanAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  const Text('Project Developers:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  _buildDevTile('Tharun', 'https://github.com/tharun-1605'),
                  const SizedBox(height: 6),
                  _buildDevTile('Dharaneesh', 'https://github.com/Dharaneesh20'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    }
  }

  Widget _buildDevTile(String devName, String url) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryAccent,
                  child: GithubLogoIcon(size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(devName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
            Row(
              children: [
                Text(
                  url,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.cyanAccent,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new, size: 12, color: Colors.cyanAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isOk ? AppTheme.textPrimary : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GithubLogoIcon extends StatelessWidget {
  final double size;
  final Color color;

  const GithubLogoIcon({super.key, this.size = 20, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GithubLogoPainter(color: color),
    );
  }
}

class _GithubLogoPainter extends CustomPainter {
  final Color color;
  _GithubLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final path = Path();
    path.moveTo(12, 0);
    path.cubicTo(5.37, 0, 0, 5.37, 0, 12);
    path.cubicTo(0, 17.31, 3.435, 21.795, 8.205, 23.385);
    path.cubicTo(8.805, 23.49, 9.03, 23.13, 9.03, 22.815);
    path.cubicTo(9.03, 22.53, 9.015, 21.585, 9.015, 20.535);
    path.cubicTo(5.67, 21.255, 4.965, 19.155, 4.965, 19.155);
    path.cubicTo(4.425, 17.775, 3.645, 17.415, 3.645, 17.415);
    path.cubicTo(2.55, 16.665, 3.735, 16.68, 3.735, 16.68);
    path.cubicTo(4.95, 16.77, 5.58, 17.925, 5.58, 17.925);
    path.cubicTo(6.645, 19.755, 8.385, 19.23, 9.075, 18.915);
    path.cubicTo(9.18, 18.135, 9.495, 17.61, 9.84, 17.31);
    path.cubicTo(7.17, 17.01, 4.365, 15.975, 4.365, 11.37);
    path.cubicTo(4.365, 10.065, 4.83, 8.985, 5.595, 8.145);
    path.cubicTo(5.475, 7.845, 5.055, 6.615, 5.715, 4.965);
    path.cubicTo(5.715, 4.965, 6.72, 4.65, 9.015, 6.21);
    path.cubicTo(9.975, 5.94, 11.01, 5.805, 12.045, 5.805);
    path.cubicTo(13.08, 5.805, 14.115, 5.94, 15.075, 6.21);
    path.cubicTo(17.37, 4.65, 18.375, 4.965, 18.375, 4.965);
    path.cubicTo(19.035, 6.615, 18.615, 7.845, 18.495, 8.145);
    path.cubicTo(19.26, 8.985, 19.725, 10.05, 19.725, 11.37);
    path.cubicTo(19.725, 15.99, 16.915, 17.01, 14.235, 17.31);
    path.cubicTo(14.67, 17.685, 15.045, 18.42, 15.045, 19.56);
    path.cubicTo(15.045, 21.195, 15.03, 22.515, 15.03, 22.815);
    path.cubicTo(15.03, 23.13, 15.255, 23.505, 15.87, 23.385);
    path.cubicTo(20.64, 21.795, 24, 17.31, 24, 12);
    path.cubicTo(24, 5.37, 18.63, 0, 12, 0);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

