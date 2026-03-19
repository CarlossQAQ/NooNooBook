import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/session_storage_service.dart';

class SessionProvider extends ChangeNotifier {
  final SessionStorageService _storage = SessionStorageService();
  List<Session> _sessions = [];
  List<Session> get sessions => List.unmodifiable(_sessions);

  bool _isLoaded = false;

  Future<void> loadSessions() async {
    _sessions = await _storage.loadAllSessions();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_isLoaded) await loadSessions();
  }

  Future<void> saveSession(Session session) async {
    await _storage.saveSession(session);
    // Update in-memory list
    final idx = _sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      _sessions[idx] = session;
    } else {
      _sessions.insert(0, session);
    }
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _storage.deleteSession(id);
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> updateSessionSummary(String id, Map<String, dynamic> summary) async {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _sessions[idx].summary = summary;
      await _storage.saveSession(_sessions[idx]);
      notifyListeners();
    }
  }
}
