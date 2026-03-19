import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pdf_document.dart';

class BookshelfProvider extends ChangeNotifier {
  List<PdfFolder> _folders = [];
  List<PdfDocument> _documents = [];
  bool _isLoaded = false;

  List<PdfFolder> get folders => List.unmodifiable(_folders);
  List<PdfDocument> get documents => List.unmodifiable(_documents);
  List<PdfDocument> get favorites => _documents.where((d) => d.isFavorite).toList();

  List<PdfDocument> getDocumentsInFolder(String? folderId) {
    return _documents.where((d) => d.folderId == folderId).toList();
  }

  List<PdfDocument> get uncategorized => _documents.where((d) => d.folderId == null).toList();

  Future<Directory> get _pdfDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/simulnote_pdfs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> get _metadataFile async {
    final dir = await _pdfDir;
    return File('${dir.path}/metadata.json');
  }

  Future<void> ensureLoaded() async {
    if (!_isLoaded) await _load();
  }

  Future<void> _load() async {
    try {
      final file = await _metadataFile;
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _folders = (data['folders'] as List?)?.map((f) => PdfFolder.fromJson(f)).toList() ?? [];
        _documents = (data['documents'] as List?)?.map((d) => PdfDocument.fromJson(d)).toList() ?? [];
      }
    } catch (_) {}
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = await _metadataFile;
    await file.writeAsString(jsonEncode({
      'folders': _folders.map((f) => f.toJson()).toList(),
      'documents': _documents.map((d) => d.toJson()).toList(),
    }));
  }

  // ── Folder CRUD ──

  Future<void> createFolder(String name) async {
    final folder = PdfFolder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
    );
    _folders.add(folder);
    notifyListeners();
    await _save();
  }

  Future<void> renameFolder(String id, String newName) async {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx >= 0) {
      _folders[idx].name = newName;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteFolder(String id) async {
    // 把文件夹内的 PDF 移到根目录
    for (final doc in _documents) {
      if (doc.folderId == id) doc.folderId = null;
    }
    _folders.removeWhere((f) => f.id == id);
    notifyListeners();
    await _save();
  }

  // ── PDF 导入 ──

  Future<PdfDocument?> importPdf({String? folderId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return null;
    final pickedFile = result.files.first;
    if (pickedFile.path == null) return null;

    final dir = await _pdfDir;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = '$id.pdf';
    final destPath = '${dir.path}/$fileName';

    // 复制 PDF 到 app 目录
    await File(pickedFile.path!).copy(destPath);

    final title = pickedFile.name.replaceAll('.pdf', '').replaceAll('.PDF', '');
    final doc = PdfDocument(
      id: id,
      title: title,
      filePath: fileName,
      folderId: folderId,
      createdAt: DateTime.now(),
    );

    _documents.add(doc);
    notifyListeners();
    await _save();
    return doc;
  }

  /// 获取 PDF 的完整文件路径
  Future<String> getFullPath(PdfDocument doc) async {
    final dir = await _pdfDir;
    return '${dir.path}/${doc.filePath}';
  }

  // ── 收藏 ──

  bool isFavorite(String docId) {
    final idx = _documents.indexWhere((d) => d.id == docId);
    return idx >= 0 && _documents[idx].isFavorite;
  }

  Future<void> toggleFavorite(String docId) async {
    final idx = _documents.indexWhere((d) => d.id == docId);
    if (idx >= 0) {
      _documents[idx].isFavorite = !_documents[idx].isFavorite;
      notifyListeners();
      await _save();
    }
  }

  // ── 重命名 ──

  Future<void> renamePdf(String docId, String newTitle) async {
    final idx = _documents.indexWhere((d) => d.id == docId);
    if (idx >= 0) {
      _documents[idx].title = newTitle;
      notifyListeners();
      await _save();
    }
  }

  // ── 移动 PDF ──

  Future<void> movePdf(String docId, String? folderId) async {
    final idx = _documents.indexWhere((d) => d.id == docId);
    if (idx >= 0) {
      _documents[idx].folderId = folderId;
      notifyListeners();
      await _save();
    }
  }

  // ── 删除 PDF ──

  Future<void> deletePdf(String docId) async {
    final idx = _documents.indexWhere((d) => d.id == docId);
    if (idx >= 0) {
      try {
        final dir = await _pdfDir;
        final file = File('${dir.path}/${_documents[idx].filePath}');
        if (await file.exists()) await file.delete();
        // 删除批注
        final annoFile = File('${dir.path}/annotations/$docId.json');
        if (await annoFile.exists()) await annoFile.delete();
      } catch (_) {}
      _documents.removeAt(idx);
      notifyListeners();
      await _save();
    }
  }
}
