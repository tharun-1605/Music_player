import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_providers.dart';
import '../theme/app_theme.dart';

class CastDialog extends ConsumerStatefulWidget {
  const CastDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CastDialog(),
    );
  }

  @override
  ConsumerState<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends ConsumerState<CastDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(castServiceProvider).startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final castService = ref.watch(castServiceProvider);
    final isCasting = castService.isCasting;
    final selectedDevice = castService.selectedDevice;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Row(
        children: [
          Icon(
            isCasting ? Icons.cast_connected : Icons.cast,
            color: isCasting ? AppTheme.primaryAccent : Colors.white,
          ),
          const SizedBox(width: 12),
          const Text('Cast Output Target', style: TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Local Device Tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: !isCasting ? AppTheme.primaryAccent : Colors.white12,
                child: Icon(Icons.phone_android, color: !isCasting ? Colors.black : Colors.white),
              ),
              title: const Text('This Device (Local)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              subtitle: const Text('Play audio on speaker / headphones', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              trailing: !isCasting ? const Icon(Icons.check_circle, color: AppTheme.primaryAccent) : null,
              onTap: () async {
                await castService.disconnect();
                if (context.mounted) Navigator.pop(context);
              },
            ),

            const Divider(color: Colors.white10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chromecast Devices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                if (castService.isDiscovering)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent)),
              ],
            ),
            const SizedBox(height: 8),

            if (castService.discoveredDevices.isEmpty && !castService.isDiscovering)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No Cast devices found on Wi-Fi network.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              )
            else
              ...castService.discoveredDevices.map((device) {
                final isSelected = selectedDevice?.id == device.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? AppTheme.primaryAccent : Colors.white10,
                    child: Icon(Icons.cast, color: isSelected ? Colors.black : Colors.white),
                  ),
                  title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  subtitle: Text('IP: ${device.host}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: isSelected
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                          onPressed: () async {
                            await castService.disconnect();
                          },
                          child: const Text('Disconnect'),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent, foregroundColor: Colors.black),
                          onPressed: () async {
                            await castService.connectToDevice(device);
                            final playerService = ref.read(audioPlayerServiceProvider);
                            if (playerService.currentSong != null) {
                              castService.castSong(playerService.currentSong!);
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Connect'),
                        ),
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }
}
