import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EqualizerPreset {
  final String name;
  final List<double> gains; // 10 bands gains in dB
  final bool isBuiltIn;

  const EqualizerPreset({
    required this.name,
    required this.gains,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'gains': gains,
        'isBuiltIn': isBuiltIn,
      };

  factory EqualizerPreset.fromJson(Map<String, dynamic> json) => EqualizerPreset(
        name: json['name'] as String,
        gains: (json['gains'] as List).map((e) => (e as num).toDouble()).toList(),
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      );
}

class EqualizerService extends ChangeNotifier {
  static final EqualizerService _instance = EqualizerService._internal();
  factory EqualizerService() => _instance;
  EqualizerService._internal() {
    _loadFromPrefs();
  }

  static const String _prefsKey = 'equalizer_settings_v1';
  static const List<String> kFrequencies = [
    '31 Hz',
    '62 Hz',
    '125 Hz',
    '250 Hz',
    '500 Hz',
    '1 kHz',
    '2 kHz',
    '4 kHz',
    '8 kHz',
    '16 kHz',
  ];

  bool _enabled = true;
  double _preamp = 0.0; // dB (-12.0 to +12.0)
  List<double> _bandGains = List.filled(10, 0.0);
  String _currentPresetName = 'Flat';
  final List<EqualizerPreset> _customPresets = [];

  bool get enabled => _enabled;
  double get preamp => _preamp;
  List<double> get bandGains => List.unmodifiable(_bandGains);
  String get currentPresetName => _currentPresetName;
  List<EqualizerPreset> get customPresets => List.unmodifiable(_customPresets);

  static final Map<String, List<double>> kBuiltInPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [6.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Reducer': [-6.0, -5.0, -3.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Treble Boost': [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 3.0, 5.0, 6.0, 7.0],
    'Treble Reducer': [0.0, 0.0, 0.0, 0.0, 0.0, -1.0, -3.0, -5.0, -6.0, -7.0],
    'Vocal': [-2.0, -1.0, 1.0, 3.0, 4.0, 4.0, 3.0, 1.0, 0.0, -1.0],
    'Acoustic': [3.0, 2.0, 1.0, 0.0, 1.0, 1.0, 2.0, 3.0, 3.0, 2.0],
    'Classical': [4.0, 3.0, 2.0, 2.0, -1.0, -1.0, 0.0, 2.0, 3.0, 3.0],
    'Electronic': [5.0, 4.0, 1.0, 0.0, -2.0, 2.0, 1.0, 1.0, 4.0, 5.0],
    'Hip-Hop': [6.0, 5.0, 2.0, 1.0, -1.0, -1.0, 1.0, -1.0, 2.0, 3.0],
    'Jazz': [3.0, 2.0, 1.0, 2.0, -2.0, -2.0, 0.0, 1.0, 2.0, 3.0],
    'Pop': [-1.0, 1.0, 3.0, 4.0, 4.0, 3.0, 1.0, -1.0, -2.0, -2.0],
    'Rock': [5.0, 4.0, 2.0, 0.0, -1.0, 0.0, 2.0, 3.0, 4.0, 4.0],
    'R&B': [4.0, 6.0, 3.0, 1.0, -2.0, -1.0, 1.0, 2.0, 3.0, 3.0],
    'Dance': [6.0, 5.0, 2.0, 0.0, 0.0, 2.0, 3.0, 4.0, 4.0, 0.0],
    'Loudness': [6.0, 4.0, 1.0, 0.0, -1.0, 0.0, -1.0, 1.0, 5.0, 2.0],
  };

  /// Preamp Headroom calculation to avoid DSP clipping
  double get effectivePreampHeadroom {
    double maxBoost = 0.0;
    for (final gain in _bandGains) {
      if (gain > maxBoost) maxBoost = gain;
    }
    return -maxBoost;
  }

  void setEnabled(bool val) {
    _enabled = val;
    _saveToPrefs();
    notifyListeners();
  }

  void setPreamp(double val) {
    _preamp = val.clamp(-12.0, 12.0);
    _saveToPrefs();
    notifyListeners();
  }

  void setBandGain(int index, double gain) {
    if (index >= 0 && index < _bandGains.length) {
      _bandGains[index] = gain.clamp(-12.0, 12.0);
      _currentPresetName = 'Custom';
      _saveToPrefs();
      notifyListeners();
    }
  }

  void selectPreset(String name) {
    if (kBuiltInPresets.containsKey(name)) {
      _currentPresetName = name;
      _bandGains = List<double>.from(kBuiltInPresets[name]!);
      _saveToPrefs();
      notifyListeners();
      return;
    }

    final customIdx = _customPresets.indexWhere((p) => p.name == name);
    if (customIdx != -1) {
      _currentPresetName = name;
      _bandGains = List<double>.from(_customPresets[customIdx].gains);
      _saveToPrefs();
      notifyListeners();
    }
  }

  void reset() {
    _enabled = true;
    _preamp = 0.0;
    _currentPresetName = 'Flat';
    _bandGains = List<double>.from(kBuiltInPresets['Flat']!);
    _saveToPrefs();
    notifyListeners();
  }

  bool saveCustomPreset(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || kBuiltInPresets.containsKey(cleanName)) return false;

    final existingIdx = _customPresets.indexWhere((p) => p.name.toLowerCase() == cleanName.toLowerCase());
    final newPreset = EqualizerPreset(name: cleanName, gains: List<double>.from(_bandGains));

    if (existingIdx != -1) {
      _customPresets[existingIdx] = newPreset;
    } else {
      _customPresets.add(newPreset);
    }

    _currentPresetName = cleanName;
    _saveToPrefs();
    notifyListeners();
    return true;
  }

  bool renameCustomPreset(String oldName, String newName) {
    final cleanNew = newName.trim();
    if (cleanNew.isEmpty || kBuiltInPresets.containsKey(cleanNew)) return false;

    final idx = _customPresets.indexWhere((p) => p.name == oldName);
    if (idx != -1) {
      _customPresets[idx] = EqualizerPreset(name: cleanNew, gains: _customPresets[idx].gains);
      if (_currentPresetName == oldName) {
        _currentPresetName = cleanNew;
      }
      _saveToPrefs();
      notifyListeners();
      return true;
    }
    return false;
  }

  void deleteCustomPreset(String name) {
    _customPresets.removeWhere((p) => p.name == name);
    if (_currentPresetName == name) {
      selectPreset('Flat');
    } else {
      _saveToPrefs();
      notifyListeners();
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _enabled = map['enabled'] as bool? ?? true;
        _preamp = (map['preamp'] as num? ?? 0.0).toDouble();
        _currentPresetName = map['currentPresetName'] as String? ?? 'Flat';

        if (map['bandGains'] != null) {
          final list = (map['bandGains'] as List).map((e) => (e as num).toDouble()).toList();
          if (list.length == 10) {
            _bandGains = list;
          }
        }

        if (map['customPresets'] != null) {
          _customPresets.clear();
          for (final item in map['customPresets'] as List) {
            _customPresets.add(EqualizerPreset.fromJson(item as Map<String, dynamic>));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading equalizer prefs: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'enabled': _enabled,
        'preamp': _preamp,
        'currentPresetName': _currentPresetName,
        'bandGains': _bandGains,
        'customPresets': _customPresets.map((p) => p.toJson()).toList(),
      };
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving equalizer prefs: $e');
    }
  }
}
