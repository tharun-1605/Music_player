import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_providers.dart';
import '../../services/equalizer_service.dart';
import '../../theme/app_theme.dart';

class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  void _showSavePresetDialog(BuildContext context, EqualizerService eq) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Save Custom Preset', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Preset Name (e.g. Extra Bass)',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final ok = eq.saveCustomPreset(name);
                if (ok) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved custom preset "$name"')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid name or built-in preset clash'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenamePresetDialog(BuildContext context, EqualizerService eq, String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('Rename "$oldName"', style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'New Name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final ok = eq.renameCustomPreset(oldName, newName);
                if (ok) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed preset to "$newName"')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid name or preset name conflict'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerServiceProvider);

    final allPresetNames = [
      ...EqualizerService.kBuiltInPresets.keys,
      ...eq.customPresets.map((p) => p.name),
    ];
    if (!allPresetNames.contains(eq.currentPresetName)) {
      allPresetNames.add(eq.currentPresetName);
    }

    final isCustomPreset = eq.customPresets.any((p) => p.name == eq.currentPresetName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer & Audio Presets'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryAccent, size: 20),
            label: const Text('Reset', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
            onPressed: () => eq.reset(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // EQ Master Enable Switch
          Card(
            color: AppTheme.surfaceColor,
            child: SwitchListTile(
              activeThumbColor: AppTheme.primaryAccent,
              title: const Text('Enable Equalizer', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              subtitle: Text(
                eq.enabled ? 'Global DSP active' : 'Equalizer bypassed',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              value: eq.enabled,
              onChanged: (val) => eq.setEnabled(val),
            ),
          ),

          const SizedBox(height: 16),

          // Preset Selection Dropdown Row
          Card(
            color: AppTheme.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Audio Preset',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.save_outlined, color: AppTheme.primaryAccent, size: 22),
                            tooltip: 'Save Custom Preset',
                            onPressed: () => _showSavePresetDialog(context, eq),
                          ),
                          if (isCustomPreset) ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.cyanAccent, size: 20),
                              tooltip: 'Rename Preset',
                              onPressed: () => _showRenamePresetDialog(context, eq, eq.currentPresetName),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Delete Preset',
                              onPressed: () => eq.deleteCustomPreset(eq.currentPresetName),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: AppTheme.surfaceColor,
                        isExpanded: true,
                        value: eq.currentPresetName,
                        items: allPresetNames.map((name) {
                          final isBuiltIn = EqualizerService.kBuiltInPresets.containsKey(name);
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Row(
                              children: [
                                Icon(
                                  isBuiltIn ? Icons.equalizer : Icons.person_pin,
                                  size: 18,
                                  color: isBuiltIn ? AppTheme.primaryAccent : Colors.cyanAccent,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: eq.currentPresetName == name ? AppTheme.primaryAccent : AppTheme.textPrimary,
                                    fontWeight: eq.currentPresetName == name ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) eq.selectPreset(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Preamp & Anti-Clipping Headroom Card
          Card(
            color: AppTheme.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Preamp Gain', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text(
                        '${eq.preamp >= 0 ? "+" : ""}${eq.preamp.toStringAsFixed(1)} dB',
                        style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    activeColor: AppTheme.primaryAccent,
                    inactiveColor: Colors.white24,
                    min: -12.0,
                    max: 12.0,
                    divisions: 48,
                    value: eq.preamp,
                    onChanged: eq.enabled ? (val) => eq.setPreamp(val) : null,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Headroom Guard: ${eq.effectivePreampHeadroom.toStringAsFixed(1)} dB headroom reserved to prevent digital clipping.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 10-Band Equalizer Sliders Container
          Card(
            color: AppTheme.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('10-Band Equalizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(10, (idx) {
                          final freqLabel = EqualizerService.kFrequencies[idx];
                          final gain = eq.bandGains[idx];

                          return SizedBox(
                            width: 44,
                            child: Column(
                              children: [
                                Text(
                                  '${gain >= 0 ? "+" : ""}${gain.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: gain > 0
                                        ? Colors.greenAccent
                                        : gain < 0
                                            ? Colors.orangeAccent
                                            : AppTheme.textMuted,
                                  ),
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: const SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                      ),
                                      child: Slider(
                                        activeColor: AppTheme.primaryAccent,
                                        inactiveColor: Colors.white12,
                                        min: -12.0,
                                        max: 12.0,
                                        divisions: 48,
                                        value: gain,
                                        onChanged: eq.enabled ? (val) => eq.setBandGain(idx, val) : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  freqLabel,
                                  style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
