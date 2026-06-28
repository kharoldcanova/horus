import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PreferencesRepository {
  static const _fileName = 'preferences.json';

  Map<String, dynamic>? _cache;

  static const Map<String, dynamic> _defaults = {
    'sensitivity': 0.5,
    'minBpm': 30.0,
    'maxBpm': 220.0,
    'vibrationFeedback': true,
    'autoFeedback': false,
  };

  Future<String> get _filePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  Future<Map<String, dynamic>> load() async {
    if (_cache != null) return _cache!;
    try {
      final path = await _filePath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _cache = Map<String, dynamic>.from(json);
        return _cache!;
      }
    } on FileSystemException catch (_) {
      // ignore
    } on FormatException catch (_) {
      // ignore
    }
    _cache = Map<String, dynamic>.from(_defaults);
    return _cache!;
  }

  Future<void> save(Map<String, dynamic> prefs) async {
    _cache = Map<String, dynamic>.from(prefs);
    try {
      final path = await _filePath;
      await File(path).writeAsString(jsonEncode(_cache!));
    } on FileSystemException catch (_) {
      // ignore
    }
  }

  Future<void> _set(String key, dynamic value) async {
    final prefs = await load();
    prefs[key] = value;
    await save(prefs);
  }

  Future<double> getSensitivity() async {
    final prefs = await load();
    return (prefs['sensitivity'] as num?)?.toDouble() ??
        (_defaults['sensitivity'] as num).toDouble();
  }

  Future<void> setSensitivity(double value) => _set('sensitivity', value);

  Future<double> getMinBpm() async {
    final prefs = await load();
    return (prefs['minBpm'] as num?)?.toDouble() ??
        (_defaults['minBpm'] as num).toDouble();
  }

  Future<void> setMinBpm(double value) => _set('minBpm', value);

  Future<double> getMaxBpm() async {
    final prefs = await load();
    return (prefs['maxBpm'] as num?)?.toDouble() ??
        (_defaults['maxBpm'] as num).toDouble();
  }

  Future<void> setMaxBpm(double value) => _set('maxBpm', value);

  Future<bool> getVibrationFeedback() async {
    final prefs = await load();
    return (prefs['vibrationFeedback'] as bool?) ?? _defaults['vibrationFeedback'] as bool;
  }

  Future<void> setVibrationFeedback(bool value) =>
      _set('vibrationFeedback', value);

  Future<bool> getAutoFeedback() async {
    final prefs = await load();
    return (prefs['autoFeedback'] as bool?) ?? _defaults['autoFeedback'] as bool;
  }

  Future<void> setAutoFeedback(bool value) => _set('autoFeedback', value);
}
