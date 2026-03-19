import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../services/audio_service.dart';

class SubtitleItem {
  final String id;
  String sourceText;       // 可变：打字机效果中会不断追加
  String translatedText;
  bool isFinalized;        // true = 句子完成，已发翻译
  final DateTime timestamp;

  SubtitleItem(this.sourceText, this.translatedText, {String? id, this.isFinalized = false})
      : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = DateTime.now();
}

class InterpretationProvider extends ChangeNotifier {
  final AudioService _audioService = AudioService();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  final List<SubtitleItem> _subtitleItems = [];
  List<SubtitleItem> get subtitleItems => List.unmodifiable(_subtitleItems);

  String _direction = 'EN_ZH';
  String get direction => _direction;

  Timer? _chunkTimer;
  int _chunkIndex = 0;

  // 打字机状态：当前活跃行的累积文本
  String _activeLine = '';

  // Session 集成
  SessionProvider? sessionProvider;
  Session? _currentSession;
  Session? get currentSession => _currentSession;

  // 查看历史会话模式
  Session? _viewingSession;
  Session? get viewingSession => _viewingSession;
  bool get isViewingHistory => _viewingSession != null;

  void setDirection(String dir) {
    if (_isRecording) return;
    _direction = dir;
    notifyListeners();
  }

  /// 加载历史会话（只读查看）
  void viewSession(Session session) {
    if (_isRecording) return;
    _viewingSession = session;
    _subtitleItems.clear();
    for (final item in session.items) {
      _subtitleItems.add(SubtitleItem(
        item.sourceText, item.translatedText,
        isFinalized: true,
      ));
    }
    notifyListeners();
  }

  /// 新建会话（清空当前内容）
  void newSession() {
    if (_isRecording) return;
    _viewingSession = null;
    _subtitleItems.clear();
    _activeLine = '';
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      await stopInterpretation();
    } else {
      await startInterpretation();
    }
  }

  Future<void> startInterpretation() async {
    final hasPermission = await _audioService.checkPermission();
    if (!hasPermission) {
      _addSystemMessage("Microphone permission denied.");
      return;
    }

    _viewingSession = null; // 退出查看模式
    _isRecording = true;
    _chunkIndex = 0;
    _subtitleItems.clear();
    _activeLine = '';

    final now = DateTime.now();
    _currentSession = Session(
      id: now.millisecondsSinceEpoch.toString(),
      title: 'Session ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      startTime: now,
      direction: _direction,
    );

    notifyListeners();

    await _audioService.resetContext();

    _startNextChunk();

    _chunkTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _cycleChunk();
    });
  }

  Future<void> stopInterpretation() async {
    _chunkTimer?.cancel();
    _isRecording = false;
    _pendingChunks.clear();
    notifyListeners();

    final path = await _audioService.stopRecording();
    if (path != null) {
      await _processChunk(path);
    }

    // 把最后的活跃行也结束掉
    _finalizeActiveLine();

    await _saveCurrentSession();
  }

  /// 把当前活跃行强制结束并翻译
  void _finalizeActiveLine() {
    if (_activeLine.trim().isEmpty) return;

    final lastItem = _subtitleItems.isNotEmpty ? _subtitleItems.last : null;
    if (lastItem != null && !lastItem.isFinalized) {
      lastItem.sourceText = _activeLine.trim();
      lastItem.isFinalized = true;
      notifyListeners();
      _translateItem(lastItem);
    }
    _activeLine = '';
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSession == null || sessionProvider == null) return;

    _currentSession!.endTime = DateTime.now();
    _currentSession!.items.clear();

    for (final item in _subtitleItems) {
      if (item.sourceText == 'System Notification') continue;
      _currentSession!.items.add(SubtitleItemData(
        sourceText: item.sourceText,
        translatedText: item.translatedText,
        timestamp: item.timestamp.toIso8601String(),
      ));
    }

    if (_currentSession!.items.isNotEmpty) {
      final firstText = _currentSession!.items.first.sourceText;
      _currentSession!.title = firstText.length > 30
          ? '${firstText.substring(0, 30)}...'
          : firstText;
      await sessionProvider!.saveSession(_currentSession!);
    }
  }

  // 处理队列：防止多个 chunk 并发处理导致竞态
  final List<String> _pendingChunks = [];
  bool _isProcessing = false;

  Future<void> _startNextChunk() async {
    await _audioService.startRecording('chunk_$_chunkIndex');
    _chunkIndex++;
  }

  Future<void> _cycleChunk() async {
    final path = await _audioService.stopRecording();
    _startNextChunk();

    if (path != null) {
      _pendingChunks.add(path);
      _drainQueue();
    }
  }

  Future<void> _drainQueue() async {
    if (_isProcessing) return; // 已有 chunk 在处理，等它完成后会继续
    _isProcessing = true;

    while (_pendingChunks.isNotEmpty) {
      final path = _pendingChunks.removeAt(0);
      try {
        await _processChunk(path);
      } catch (e) {
        // 防止单个 chunk 异常阻塞队列
      }
    }

    _isProcessing = false;
  }

  /// 打字机效果：收到文本 → 追加到活跃行 → 检测句末断句
  Future<void> _processChunk(String filePath) async {
    final sttResponse = await _audioService.uploadAudio(filePath, direction: _direction);

    if (sttResponse == null) {
      _addSystemMessage("[Backend disconnected. Check localhost:8000]");
      return;
    }

    try {
      final sttData = jsonDecode(sttResponse);
      final String newText = sttData['transcription'] ?? '';

      if (newText.isEmpty) return;

      // 追加到活跃行
      if (_activeLine.isNotEmpty) {
        _activeLine = '$_activeLine $newText';
      } else {
        _activeLine = newText;
      }

      // 检查是否有完整句子
      final sentences = _splitSentences(_activeLine);

      if (sentences.length > 1) {
        // 有完整句子：前 N-1 段是完整的，最后一段可能是半句
        for (int i = 0; i < sentences.length - 1; i++) {
          final sentence = sentences[i].trim();
          if (sentence.isEmpty) continue;
          // 跳过纯标点句子（如 "." ".." "..."）
          if (sentence.replaceAll(RegExp(r'[.?!。？！\s]'), '').isEmpty) continue;

          // 结束当前活跃行的 item
          final lastItem = _subtitleItems.isNotEmpty ? _subtitleItems.last : null;
          if (lastItem != null && !lastItem.isFinalized) {
            lastItem.sourceText = sentence;
            lastItem.isFinalized = true;
            notifyListeners();
            _translateItem(lastItem);
          } else {
            // 创建新的已完成 item
            final item = SubtitleItem(sentence, '翻译中...', isFinalized: true);
            _subtitleItems.add(item);
            notifyListeners();
            _translateItem(item);
          }
        }

        // 最后一段作为新的活跃行
        _activeLine = sentences.last.trim();
        if (_activeLine.isNotEmpty) {
          // 创建新的未完成 item 显示打字效果
          final item = SubtitleItem(_activeLine, '', isFinalized: false);
          _subtitleItems.add(item);
          notifyListeners();
        }
      } else {
        // 没有完整句子，更新当前活跃行的显示
        final lastItem = _subtitleItems.isNotEmpty ? _subtitleItems.last : null;
        if (lastItem != null && !lastItem.isFinalized) {
          // 更新现有未完成 item（打字效果）
          lastItem.sourceText = _activeLine;
          notifyListeners();
        } else {
          // 创建新的未完成 item
          final item = SubtitleItem(_activeLine, '', isFinalized: false);
          _subtitleItems.add(item);
          notifyListeners();
        }
      }
    } catch (e) {
      _addSystemMessage("[Response Error]: $sttResponse");
    }
  }

  /// 拆分句子：按句末标点分割（忽略省略号等）
  List<String> _splitSentences(String text) {
    final parts = <String>[];
    var current = '';

    for (int i = 0; i < text.length; i++) {
      current += text[i];
      final ch = text[i];
      if ('.?!。？！'.contains(ch)) {
        // 跳过省略号 ... 和连续标点
        final nextIdx = i + 1;
        if (ch == '.' && nextIdx < text.length && text[nextIdx] == '.') {
          continue; // 省略号的一部分，不断句
        }
        // 句子至少要有 3 个非标点字符才算有效句子
        final stripped = current.replaceAll(RegExp(r'[.?!。？！\s]'), '');
        if (stripped.length >= 3) {
          parts.add(current);
          current = '';
        }
      }
    }
    if (current.isNotEmpty) {
      parts.add(current);
    }

    return parts;
  }

  /// 异步翻译一个 item
  Future<void> _translateItem(SubtitleItem item) async {
    final transResponse = await _audioService.translateText(item.sourceText, direction: _direction);
    if (transResponse != null) {
      final transData = jsonDecode(transResponse);
      item.translatedText = transData['translation'] ?? '';
    } else {
      item.translatedText = '[翻译失败]';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> generateSummary() async {
    final fallback = {
      'topic': '',
      'key_points': <String>[],
      'action_items': <String>[],
      'decisions': <String>[],
      'brief_summary': 'No text to summarize.'
    };

    if (_subtitleItems.isEmpty) return fallback;

    try {
      final transcriptionLog = _subtitleItems
          .where((s) => s.sourceText != 'System Notification')
          .map((s) => s.sourceText)
          .join(" ");
      if (transcriptionLog.trim().isEmpty) return fallback;

      final res = await _audioService.summarizeAudio(transcriptionLog);
      if (res != null) {
        final data = jsonDecode(res);
        final summary = data['summary'];
        if (summary is Map<String, dynamic>) {
          return summary;
        }
      }
    } catch (e) {
      return {...fallback, 'brief_summary': 'Network Error: $e'};
    }
    return fallback;
  }

  void _addSystemMessage(String msg) {
    _subtitleItems.add(SubtitleItem("System Notification", msg, isFinalized: true));
    notifyListeners();
  }

  @override
  void dispose() {
    _chunkTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
