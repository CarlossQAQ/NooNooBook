import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';

class SessionStorageService {
  Future<Directory> get _sessionDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/simulnote_sessions');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> saveSession(Session session) async {
    final dir = await _sessionDir;
    final file = File('${dir.path}/${session.id}.json');
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<List<Session>> loadAllSessions() async {
    final dir = await _sessionDir;
    if (!await dir.exists()) return [];

    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    final sessions = <Session>[];

    for (final file in files) {
      try {
        final content = await file.readAsString();
        sessions.add(Session.fromJson(jsonDecode(content)));
      } catch (_) {
        // skip corrupt files
      }
    }

    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  Future<void> deleteSession(String id) async {
    final dir = await _sessionDir;
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
