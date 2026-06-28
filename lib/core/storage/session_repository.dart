import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../sensors/sensor_event.dart';

class SessionRepository {
  static const _sessionsDir = 'sessions';

  Future<String> get _documentsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> get _sessionsPath async {
    final base = await _documentsDir;
    return '$base/$_sessionsDir';
  }

  Future<Directory> _ensureSessionsDir() async {
    final dir = Directory(await _sessionsPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _indexPath() async {
    final base = await _documentsDir;
    return '$base/sessions_index.json';
  }

  Future<List<Map<String, dynamic>>> _readIndex() async {
    try {
      final path = await _indexPath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        return (jsonDecode(content) as List).cast<Map<String, dynamic>>();
      }
    } on FileSystemException catch (_) {
      // ignore
    } on FormatException catch (_) {
      // ignore
    }
    return [];
  }

  Future<void> _writeIndex(List<Map<String, dynamic>> index) async {
    final path = await _indexPath();
    await File(path).writeAsString(jsonEncode(index));
  }

  /// Save a SensorSession to a JSON file in the app documents directory.
  /// Returns the file path on success.
  Future<String> saveSession(SensorSession session) async {
    await _ensureSessionsDir();
    final sessionsPath = await _sessionsPath;
    final filePath = '$sessionsPath/${session.id}.json';

    final json = session.toJson();
    await File(filePath).writeAsString(jsonEncode(json));

    final index = await _readIndex();
    index.removeWhere((entry) => entry['id'] == session.id);
    index.add({
      'id': session.id,
      'startTime': session.startTime.toIso8601String(),
      'notes': session.notes,
      'eventCount': session.events.length,
      'duration': session.duration.inMilliseconds / 1000.0,
      if (session.audioSamples != null)
        'audioSampleCount': session.audioSamples!.length,
    });
    await _writeIndex(index);

    return filePath;
  }

  /// Load a specific session by id.
  Future<SensorSession?> loadSession(String id) async {
    try {
      final sessionsPath = await _sessionsPath;
      final filePath = '$sessionsPath/$id.json';
      final file = File(filePath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return SensorSession.fromJson(json);
    } on FileSystemException catch (_) {
      return null;
    } on FormatException catch (_) {
      return null;
    }
  }

  /// List all saved session metadata (id, startTime, notes, eventCount,
  /// duration). Returns a list of maps for display in HistoryScreen. Does NOT
  /// load full event data.
  Future<List<Map<String, dynamic>>> listSessions() async {
    final index = await _readIndex();
    index
        .sort((a, b) => (b['startTime'] as String).compareTo(
              a['startTime'] as String,
            ));
    return index;
  }

  /// Delete a session file by id.
  Future<void> deleteSession(String id) async {
    try {
      final sessionsPath = await _sessionsPath;
      final filePath = '$sessionsPath/$id.json';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final index = await _readIndex();
      index.removeWhere((entry) => entry['id'] == id);
      await _writeIndex(index);
    } on FileSystemException catch (_) {
      // ignore
    }
  }

  /// Export all sessions as a single JSON array file for training data
  /// sharing. Returns the exported file path.
  Future<String> exportSessions() async {
    await _ensureSessionsDir();
    final sessionsPath = await _sessionsPath;
    final dir = Directory(sessionsPath);
    final entities = await dir.list().toList();

    final sessions = <Map<String, dynamic>>[];
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          sessions.add(jsonDecode(content) as Map<String, dynamic>);
        } catch (_) {
          // skip corrupt files
        }
      }
    }

    final base = await _documentsDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportPath = '$base/horus_export_$timestamp.json';
    await File(exportPath).writeAsString(jsonEncode(sessions));

    return exportPath;
  }
}
