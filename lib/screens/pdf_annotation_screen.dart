import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import '../models/stroke.dart';
import '../painters/note_painter.dart';
import '../providers/bookshelf_provider.dart';
import '../providers/note_provider.dart';

enum ToolMode { mouse, pen, highlighter, eraser }
enum PanelMode { none, translate, summarize }

class PdfAnnotationScreen extends StatefulWidget {
  final String pdfId;
  final String pdfPath;
  final String title;

  const PdfAnnotationScreen({super.key, required this.pdfId, required this.pdfPath, required this.title});

  @override
  State<PdfAnnotationScreen> createState() => _PdfAnnotationScreenState();
}

class _PdfAnnotationScreenState extends State<PdfAnnotationScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  int _currentPage = 0;
  int _totalPages = 0;
  ToolMode _toolMode = ToolMode.mouse;
  PanelMode _panelMode = PanelMode.none;

  // 右侧面板状态
  final _panelInputController = TextEditingController();
  String _panelResult = '';
  Map<String, dynamic>? _panelSummaryResult;
  bool _panelLoading = false;

  bool get _isDrawing => _toolMode == ToolMode.pen || _toolMode == ToolMode.highlighter || _toolMode == ToolMode.eraser;

  @override
  void initState() {
    super.initState();
    context.read<NoteProvider>().loadAnnotations(widget.pdfId);
  }

  @override
  void dispose() {
    _panelInputController.dispose();
    super.dispose();
  }

  void _setToolMode(ToolMode mode) {
    setState(() => _toolMode = mode);
    final note = context.read<NoteProvider>();
    if (mode == ToolMode.pen) {
      note.setTool(StrokeType.pen);
    } else if (mode == ToolMode.highlighter) {
      note.setTool(StrokeType.highlighter);
    } else if (mode == ToolMode.eraser) {
      note.toggleEraser();
    }
  }

  void _togglePanel(PanelMode mode) {
    setState(() {
      if (_panelMode == mode) {
        _panelMode = PanelMode.none;
      } else {
        _panelMode = mode;
        _panelResult = '';
        _panelSummaryResult = null;
        _panelInputController.clear();
      }
    });
  }

  Future<void> _doTranslate() async {
    if (_panelInputController.text.trim().isEmpty) return;
    setState(() { _panelLoading = true; _panelResult = ''; });
    try {
      final resp = await http.post(Uri.parse('http://localhost:8000/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': _panelInputController.text.trim(), 'direction': 'EN_ZH'}));
      if (resp.statusCode == 200) setState(() => _panelResult = jsonDecode(resp.body)['translation'] ?? '');
    } catch (e) { setState(() => _panelResult = 'Error: $e'); }
    setState(() => _panelLoading = false);
  }

  Future<void> _doSummarize() async {
    if (_panelInputController.text.trim().isEmpty) return;
    setState(() { _panelLoading = true; _panelSummaryResult = null; });
    try {
      final resp = await http.post(Uri.parse('http://localhost:8000/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': _panelInputController.text.trim()}));
      if (resp.statusCode == 200) {
        final s = jsonDecode(resp.body)['summary'];
        if (s is Map<String, dynamic>) setState(() => _panelSummaryResult = s);
      }
    } catch (e) { setState(() => _panelSummaryResult = {'brief_summary': 'Error: $e'}); }
    setState(() => _panelLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final note = context.watch<NoteProvider>();
    final isFav = context.watch<BookshelfProvider>().isFavorite(widget.pdfId);

    return Scaffold(
      backgroundColor: const Color(0xFF4A4A4A),
      body: Column(
        children: [
          // ── Toolbar ──
          _buildToolbar(note, isFav),

          // ── PDF + optional side panel ──
          Expanded(
            child: Row(
              children: [
                // PDF area
                Expanded(
                  child: Stack(
                    children: [
                      PdfViewer.file(
                        widget.pdfPath,
                        controller: _pdfController,
                        params: PdfViewerParams(
                          // 绘图模式禁止滚动/缩放，鼠标模式允许
                          panEnabled: !_isDrawing,
                          // 鼠标模式下启用文本选择，绘图模式显式禁用
                          textSelectionParams: _isDrawing
                              ? const PdfTextSelectionParams(enabled: false)
                              : PdfTextSelectionParams(
                            onTextSelectionChange: (selection) async {
                              if (selection.hasSelectedText && _panelMode != PanelMode.none) {
                                final text = await selection.getSelectedText();
                                if (text.isNotEmpty) {
                                  _panelInputController.text = text;
                                  // 自动触发翻译/总结
                                  if (_panelMode == PanelMode.translate) {
                                    _doTranslate();
                                  }
                                }
                              }
                            },
                          ),
                          onPageChanged: (page) {
                            if (page != null) {
                              setState(() => _currentPage = page - 1);
                              note.setPage(page - 1);
                            }
                          },
                          onViewerReady: (document, controller) {
                            setState(() => _totalPages = document.pages.length);
                          },
                          pageOverlaysBuilder: (context, pageRect, page) {
                            // overlay 已被 pdfrx 定位在页面区域内，直接 SizedBox.expand 填满
                            final pageW = pageRect.width;
                            final pageH = pageRect.height;
                            return [
                              if (_isDrawing)
                                SizedBox.expand(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (d) {
                                      note.startStroke(Offset(d.localPosition.dx / pageW, d.localPosition.dy / pageH));
                                    },
                                    onPanUpdate: (d) {
                                      note.addPoint(Offset(d.localPosition.dx / pageW, d.localPosition.dy / pageH));
                                    },
                                    onPanEnd: (_) => note.endStroke(),
                                    child: CustomPaint(
                                      painter: NotePainter(
                                        strokes: note.strokes,
                                        activeStroke: (note.currentPage == page.pageNumber - 1) ? note.activeStroke : null,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SizedBox.expand(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: NotePainter(strokes: note.strokes, activeStroke: null),
                                    ),
                                  ),
                                ),
                            ];
                          },
                        ),
                      ),
                      // Mode indicator
                      Positioned(
                        left: 16, bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                          child: Text(
                            _toolMode == ToolMode.mouse ? 'Browse' :
                            _toolMode == ToolMode.pen ? 'Pen' :
                            _toolMode == ToolMode.highlighter ? 'Highlighter' : 'Eraser',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Right side panel ──
                if (_panelMode != PanelMode.none)
                  _buildSidePanel(),
              ],
            ),
          ),

          // ── Page nav ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: _currentPage > 0 ? () => _pdfController.goToPage(pageNumber: _currentPage) : null),
                Text('Page ${_currentPage + 1} / $_totalPages', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: _currentPage < _totalPages - 1 ? () => _pdfController.goToPage(pageNumber: _currentPage + 2) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(NoteProvider note, bool isFav) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black12))),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),

            // Mode buttons
            _toolBtn(Icons.pan_tool_alt, 'Mouse', _toolMode == ToolMode.mouse, () => _setToolMode(ToolMode.mouse)),
            _toolBtn(Icons.edit, 'Pen', _toolMode == ToolMode.pen, () => _setToolMode(ToolMode.pen)),
            _toolBtn(Icons.highlight, 'Highlight', _toolMode == ToolMode.highlighter, () => _setToolMode(ToolMode.highlighter)),
            _toolBtn(Icons.auto_fix_normal, 'Eraser', _toolMode == ToolMode.eraser, () => _setToolMode(ToolMode.eraser)),

            const _VDivider(),

            // Colors (only when drawing)
            if (_isDrawing) ...[
              ..._getColors().map((c) => GestureDetector(
                onTap: () => note.setColor(c),
                child: Container(
                  width: note.currentColor == c ? 24 : 18, height: note.currentColor == c ? 24 : 18,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: note.currentColor == c ? Border.all(color: Colors.black54, width: 2) : Border.all(color: Colors.black12),
                  ),
                ),
              )),
              const _VDivider(),
              // 预设笔触大小
              ...[3.0, 6.0, 10.0, 16.0].map((s) => GestureDetector(
                onTap: () => note.setSize(s),
                child: Tooltip(
                  message: '${s.toInt()}px',
                  child: Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: note.currentSize == s ? Colors.blueAccent : Colors.black26, width: note.currentSize == s ? 2 : 1),
                    ),
                    child: Center(
                      child: Container(
                        width: (s / 16 * 12).clamp(4, 14),
                        height: (s / 16 * 12).clamp(4, 14),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: note.currentSize == s ? Colors.blueAccent : Colors.black38),
                      ),
                    ),
                  ),
                ),
              )),
              const SizedBox(width: 4),
              SizedBox(width: 140, child: Slider(value: note.currentSize, min: 1, max: 24, onChanged: (v) => note.setSize(v))),
              const _VDivider(),
              IconButton(icon: const Icon(Icons.undo, size: 18), onPressed: () => note.undo(), tooltip: 'Undo'),
              const _VDivider(),
            ],

            // Translate / Summarize
            _toolBtn(Icons.translate, 'Translate', _panelMode == PanelMode.translate, () => _togglePanel(PanelMode.translate)),
            _toolBtn(Icons.auto_awesome, 'AI Summary', _panelMode == PanelMode.summarize, () => _togglePanel(PanelMode.summarize)),

            const _VDivider(),

            // Favorite
            IconButton(
              icon: Icon(isFav ? Icons.star : Icons.star_border, size: 20, color: isFav ? Colors.amber : null),
              onPressed: () => context.read<BookshelfProvider>().toggleFavorite(widget.pdfId),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getColors() {
    if (_toolMode == ToolMode.highlighter) {
      return const [Color(0xFFFFEB3B), Color(0xFF76FF03), Color(0xFF40C4FF), Color(0xFFFF80AB)];
    }
    return const [Colors.black, Colors.blue, Colors.red, Colors.green, Color(0xFFFF9800), Colors.purple];
  }

  Widget _buildSidePanel() {
    final isTranslate = _panelMode == PanelMode.translate;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Icon(isTranslate ? Icons.translate : Icons.auto_awesome, size: 18, color: isTranslate ? Colors.blueAccent : Colors.deepPurple),
                const SizedBox(width: 8),
                Text(isTranslate ? 'Translate' : 'AI Summary', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _panelMode = PanelMode.none)),
              ],
            ),
          ),

          // Input area
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _panelInputController,
              maxLines: 5,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: isTranslate ? 'Select text from PDF or paste here...' : 'Paste text to summarize...',
                hintStyle: const TextStyle(fontSize: 13),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _panelLoading ? null : (isTranslate ? _doTranslate : _doSummarize),
                child: _panelLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isTranslate ? 'Translate' : 'Summarize'),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Result area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: isTranslate ? _buildTranslateResult() : _buildSummarizeResult(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateResult() {
    if (_panelResult.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(_panelResult, style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }

  Widget _buildSummarizeResult() {
    if (_panelSummaryResult == null) return const SizedBox.shrink();
    final s = _panelSummaryResult!;
    final topic = s['topic'] as String? ?? '';
    final brief = s['brief_summary'] as String? ?? '';
    final points = (s['key_points'] as List?)?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topic.isNotEmpty) Text(topic, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (brief.isNotEmpty) ...[const SizedBox(height: 8), Text(brief, style: const TextStyle(fontSize: 13, height: 1.5))],
          if (points.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...points.map((p) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: Colors.deepPurple)),
                Expanded(child: Text(p, style: const TextStyle(fontSize: 12, height: 1.4))),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isActive ? Colors.blueAccent : Colors.black54),
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 5), color: Colors.black12);
}
