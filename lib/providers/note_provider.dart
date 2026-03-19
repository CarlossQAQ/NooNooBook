import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../models/stroke.dart';

class NoteProvider extends ChangeNotifier {
  // 按页存储笔迹
  final Map<int, List<Stroke>> _pageStrokes = {};
  Stroke? _activeStroke;
  int _currentPage = 0;

  Color _currentColor = Colors.black;
  double _currentSize = 6.0;
  bool _isEraser = false;
  StrokeType _currentTool = StrokeType.pen;

  String? _currentPdfId; // 当前打开的 PDF ID

  // ── Getters ──
  List<Stroke> get strokes => List.unmodifiable(_pageStrokes[_currentPage] ?? []);
  Stroke? get activeStroke => _activeStroke;
  Color get currentColor => _currentColor;
  double get currentSize => _currentSize;
  bool get isEraser => _isEraser;
  StrokeType get currentTool => _currentTool;
  int get currentPage => _currentPage;

  // ── PDF 生命周期 ──

  Future<void> loadAnnotations(String pdfId) async {
    _currentPdfId = pdfId;
    _pageStrokes.clear();
    _currentPage = 0;
    _activeStroke = null;

    try {
      final file = await _annotationFile(pdfId);
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final entry in data.entries) {
          final pageIdx = int.parse(entry.key);
          final strokeList = (entry.value as List).map((s) => _strokeFromJson(s)).toList();
          _pageStrokes[pageIdx] = strokeList;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveAnnotations() async {
    if (_currentPdfId == null) return;
    try {
      final file = await _annotationFile(_currentPdfId!);
      final data = <String, dynamic>{};
      for (final entry in _pageStrokes.entries) {
        if (entry.value.isNotEmpty) {
          data[entry.key.toString()] = entry.value.map((s) => _strokeToJson(s)).toList();
        }
      }
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  void setPage(int page) {
    if (page == _currentPage) return;
    _activeStroke = null;
    _currentPage = page;
    notifyListeners();
  }

  // ── Drawing lifecycle ──
  // 坐标全部归一化为 0~1 比例，渲染时再乘以实际页面尺寸

  void startStroke(Offset normalizedPos) {
    if (_isEraser) {
      _eraseAt(normalizedPos);
      return;
    }
    _activeStroke = Stroke(
      points: [PointVector(normalizedPos.dx, normalizedPos.dy)],
      color: _currentTool == StrokeType.highlighter
          ? _currentColor.withValues(alpha: 0.4)
          : _currentColor,
      size: _currentTool == StrokeType.highlighter ? _currentSize * 3 : _currentSize,
      type: _currentTool,
      pageIndex: _currentPage,
    );
    notifyListeners();
  }

  void addPoint(Offset normalizedPos) {
    if (_isEraser) {
      _eraseAt(normalizedPos);
      return;
    }
    if (_activeStroke == null) return;
    // 直接 in-place 添加，不做 copyWith 避免整个列表拷贝
    _activeStroke!.addPoint(PointVector(normalizedPos.dx, normalizedPos.dy));
    notifyListeners();
  }

  void endStroke() {
    if (_isEraser) return;
    if (_activeStroke == null) return;
    if (_activeStroke!.points.isNotEmpty) {
      _pageStrokes.putIfAbsent(_currentPage, () => []);
      _pageStrokes[_currentPage]!.add(_activeStroke!);
    }
    _activeStroke = null;
    notifyListeners();
    saveAnnotations(); // 自动保存
  }

  // ── Eraser ──

  void _eraseAt(Offset normalizedPos) {
    final pageList = _pageStrokes[_currentPage];
    if (pageList == null || pageList.isEmpty) return;

    // 归一化坐标下的擦除半径（约 2% 页面宽度）
    const double eraserRadiusSq = 0.0004; // 0.02^2
    bool erased = false;

    for (int i = pageList.length - 1; i >= 0; i--) {
      for (final pt in pageList[i].points) {
        final dx = pt.x - normalizedPos.dx;
        final dy = pt.y - normalizedPos.dy;
        if ((dx * dx + dy * dy) < eraserRadiusSq) {
          pageList.removeAt(i);
          erased = true;
          break;
        }
      }
    }

    if (erased) {
      notifyListeners();
      saveAnnotations();
    }
  }

  // ── Tool controls ──

  void setColor(Color color) {
    _currentColor = color;
    _isEraser = false;
    notifyListeners();
  }

  void setSize(double size) {
    _currentSize = size;
    notifyListeners();
  }

  void setTool(StrokeType tool) {
    _currentTool = tool;
    _isEraser = false;
    notifyListeners();
  }

  void toggleEraser() {
    _isEraser = !_isEraser;
    notifyListeners();
  }

  void clearPage() {
    _pageStrokes[_currentPage]?.clear();
    _activeStroke = null;
    notifyListeners();
    saveAnnotations();
  }

  void undo() {
    final pageList = _pageStrokes[_currentPage];
    if (pageList != null && pageList.isNotEmpty) {
      pageList.removeLast();
      notifyListeners();
      saveAnnotations();
    }
  }

  // ── Serialization helpers ──

  Future<File> _annotationFile(String pdfId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/simulnote_pdfs/annotations');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$pdfId.json');
  }

  Map<String, dynamic> _strokeToJson(Stroke s) => {
    'points': s.points.map((p) => [p.x, p.y]).toList(),
    'color': s.color.toARGB32(),
    'size': s.size,
    'type': s.type.index,
    'pageIndex': s.pageIndex,
  };

  Stroke _strokeFromJson(dynamic json) {
    final m = json as Map<String, dynamic>;
    return Stroke(
      points: (m['points'] as List).map((p) => PointVector((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
      color: Color(m['color'] as int),
      size: (m['size'] as num).toDouble(),
      type: StrokeType.values[m['type'] ?? 0],
      pageIndex: m['pageIndex'] ?? 0,
    );
  }
}
