import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pdf_document.dart';
import '../providers/bookshelf_provider.dart';
import 'pdf_annotation_screen.dart';

class FolderScreen extends StatelessWidget {
  final String folderId;
  final String folderName;

  const FolderScreen({super.key, required this.folderId, required this.folderName});

  @override
  Widget build(BuildContext context) {
    final shelf = context.watch<BookshelfProvider>();
    final docs = shelf.getDocumentsInFolder(folderId);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(color: Colors.black87),
        title: Text(folderName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: () => shelf.importPdf(folderId: folderId),
          ),
        ],
      ),
      body: docs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.black.withValues(alpha: 0.12)),
                  const SizedBox(height: 16),
                  const Text('Empty folder', style: TextStyle(color: Colors.black38, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Tap + to import a PDF', style: TextStyle(color: Colors.black26, fontSize: 14)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: docs.map((doc) => _FolderPdfCard(
                  doc: doc,
                  onTap: () => _openPdf(context, doc),
                  onFavorite: () => shelf.toggleFavorite(doc.id),
                  onDelete: () => shelf.deletePdf(doc.id),
                )).toList(),
              ),
            ),
    );
  }

  void _openPdf(BuildContext context, PdfDocument doc) async {
    final path = await context.read<BookshelfProvider>().getFullPath(doc);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PdfAnnotationScreen(pdfId: doc.id, pdfPath: path, title: doc.title),
    ));
  }
}

class _FolderPdfCard extends StatelessWidget {
  final PdfDocument doc;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _FolderPdfCard({required this.doc, required this.onTap, required this.onFavorite, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          builder: (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(doc.isFavorite ? Icons.star_border : Icons.star, color: Colors.amber),
                  title: Text(doc.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () { onFavorite(); Navigator.pop(c); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () { onDelete(); Navigator.pop(c); },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: const Icon(Icons.picture_as_pdf, size: 48, color: Colors.redAccent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(doc.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  if (doc.isFavorite)
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
