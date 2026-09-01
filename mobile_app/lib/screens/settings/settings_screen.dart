import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/music_providers.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/server_discovery_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;
  ConnectionTestResult? _testResult;
  bool _testing = false;
  bool _discovering = false;
  bool _scanning = false;
  String? _discoveryMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server & App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
        ],
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
