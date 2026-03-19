import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pdf_document.dart';
import '../providers/bookshelf_provider.dart';
import 'folder_screen.dart';
import 'pdf_annotation_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BookshelfProvider>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final shelf = context.watch<BookshelfProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black87),
        title: const Text('My Notebooks', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black54),
            onSelected: (val) {
              if (val == 'pdf') shelf.importPdf();
              if (val == 'folder') _createFolder(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 18, color: Colors.redAccent), SizedBox(width: 8), Text('Import PDF')])),
              PopupMenuItem(value: 'folder', child: Row(children: [Icon(Icons.create_new_folder, size: 18, color: Colors.amber), SizedBox(width: 8), Text('New Folder')])),
            ],
          ),
        ],
      ),
      body: shelf.folders.isEmpty && shelf.documents.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                if (shelf.favorites.isNotEmpty)
                  _buildSection(
                    icon: Icons.star_rounded,
                    label: 'Favorites',
                    iconColor: Colors.amber,
                    children: shelf.favorites.map((doc) => _DraggablePdfBook(
                      doc: doc, onTap: () => _openPdf(doc), onLongPress: () => _showPdfMenu(context, doc),
                    )).toList(),
                    folders: const [],
                  ),
                if (shelf.folders.isNotEmpty)
                  _buildSection(
                    icon: Icons.folder_rounded,
                    label: 'Folders',
                    iconColor: Colors.blueGrey,
                    children: const [],
                    folders: shelf.folders.map((f) => _DroppableFolderCard(
                      folder: f,
                      itemCount: shelf.getDocumentsInFolder(f.id).length,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(folderId: f.id, folderName: f.name))),
                      onLongPress: () => _confirmDeleteFolder(context, f),
                      onAcceptPdf: (docId) => shelf.movePdf(docId, f.id),
                    )).toList(),
                  ),
                if (shelf.uncategorized.isNotEmpty)
                  _buildSection(
                    icon: Icons.description_rounded,
                    label: 'Uncategorized',
                    iconColor: Colors.black38,
                    children: shelf.uncategorized.map((doc) => _DraggablePdfBook(
                      doc: doc, onTap: () => _openPdf(doc), onLongPress: () => _showPdfMenu(context, doc),
                    )).toList(),
                    folders: const [],
                  ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required Color iconColor,
    required List<Widget> children,
    required List<Widget> folders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.3)),
            ],
          ),
        ),
        // Content area
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ...folders,
                if (folders.isNotEmpty && children.isNotEmpty) const SizedBox(width: 12),
                ...children,
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 80, color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          const Text('Your bookshelf is empty', style: TextStyle(fontSize: 18, color: Colors.black38)),
          const SizedBox(height: 8),
          const Text('Tap + to import a PDF or create a folder', style: TextStyle(fontSize: 14, color: Colors.black26)),
        ],
      ),
    );
  }

  void _openPdf(PdfDocument doc) async {
    final path = await context.read<BookshelfProvider>().getFullPath(doc);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PdfAnnotationScreen(pdfId: doc.id, pdfPath: path, title: doc.title),
    ));
  }

  void _showPdfMenu(BuildContext context, PdfDocument doc) {
    final shelf = context.read<BookshelfProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.edit, color: Colors.blueAccent), title: const Text('Rename'), onTap: () { Navigator.pop(c); _renamePdf(context, doc); }),
            ListTile(leading: Icon(doc.isFavorite ? Icons.star : Icons.star_border, color: Colors.amber), title: Text(doc.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'), onTap: () { shelf.toggleFavorite(doc.id); Navigator.pop(c); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete'), onTap: () { shelf.deletePdf(doc.id); Navigator.pop(c); }),
          ],
        ),
      ),
    );
  }

  void _renamePdf(BuildContext context, PdfDocument doc) {
    final controller = TextEditingController(text: doc.title);
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: Colors.white, title: const Text('Rename PDF'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'New name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () { if (controller.text.trim().isNotEmpty) { context.read<BookshelfProvider>().renamePdf(doc.id, controller.text.trim()); Navigator.pop(c); }}, child: const Text('Save')),
      ],
    ));
  }

  void _createFolder(BuildContext context) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: Colors.white, title: const Text('New Folder'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () { if (controller.text.trim().isNotEmpty) { context.read<BookshelfProvider>().createFolder(controller.text.trim()); Navigator.pop(c); }}, child: const Text('Create')),
      ],
    ));
  }

  void _confirmDeleteFolder(BuildContext context, PdfFolder folder) {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: Colors.white, title: const Text('Delete Folder?'),
      content: Text('PDFs in "${folder.name}" will be moved to Uncategorized.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () { context.read<BookshelfProvider>().deleteFolder(folder.id); Navigator.pop(c); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

// ──────────── Draggable PDF Book ────────────

class _DraggablePdfBook extends StatelessWidget {
  final PdfDocument doc;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DraggablePdfBook({required this.doc, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: _BookCover(doc: doc),
          ),
          // Drag handle
          Positioned(
            top: -4, right: -4,
            child: Draggable<String>(
              data: doc.id,
              feedback: Material(elevation: 8, borderRadius: BorderRadius.circular(8), child: _BookCover(doc: doc, scale: 1.1)),
              childWhenDragging: Opacity(opacity: 0.3, child: _BookCover(doc: doc)),
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 书本封面卡片 — 3:4 比例，精致排版
class _BookCover extends StatelessWidget {
  final PdfDocument doc;
  final double scale;

  const _BookCover({required this.doc, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final w = 90.0 * scale;
    final h = 120.0 * scale; // 3:4 比例
    final hue = (doc.title.hashCode % 360).abs().toDouble();
    final baseColor = HSLColor.fromAHSL(1.0, hue, 0.25, 0.50).toColor();
    final lightColor = HSLColor.fromAHSL(1.0, hue, 0.20, 0.60).toColor();
    final isLight = baseColor.computeLuminance() > 0.4;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightColor, baseColor],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: baseColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(2, 3)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2, offset: const Offset(1, 1)),
        ],
      ),
      child: Stack(
        children: [
          // 书脊装饰线
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
              ),
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 收藏标记
                if (doc.isFavorite)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Icon(Icons.star_rounded, size: 14, color: isLight ? Colors.amber.shade700 : Colors.amber.shade300),
                  ),
                const Spacer(),
                // 标题 — 左下角对齐
                Text(
                  doc.title,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w600,
                    color: isLight ? Colors.black87 : Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // PDF 标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('PDF', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: isLight ? Colors.black54 : Colors.white70, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────── Droppable Folder Card ────────────

class _DroppableFolderCard extends StatefulWidget {
  final PdfFolder folder;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(String) onAcceptPdf;

  const _DroppableFolderCard({required this.folder, required this.itemCount, required this.onTap, required this.onLongPress, required this.onAcceptPdf});

  @override
  State<_DroppableFolderCard> createState() => _DroppableFolderCardState();
}

class _DroppableFolderCardState extends State<_DroppableFolderCard> with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) { setState(() => _isHovering = true); return true; },
      onLeave: (_) => setState(() => _isHovering = false),
      onAcceptWithDetails: (details) { setState(() => _isHovering = false); _bounceController.forward(from: 0); widget.onAcceptPdf(details.data); },
      builder: (context, candidateData, rejectedData) {
        return AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (_, child) => Transform.scale(scale: _isHovering ? 1.12 : _bounceAnimation.value, child: child),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90, height: 90,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: _isHovering ? const Color(0xFFFFF3E0) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _isHovering ? Colors.amber.shade400 : const Color(0xFFE8E8E8), width: _isHovering ? 2 : 1),
                boxShadow: _isHovering ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2)] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isHovering ? Icons.folder_open_rounded : Icons.folder_rounded, size: 32, color: _isHovering ? Colors.amber.shade700 : Colors.amber.shade600),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(widget.folder.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${widget.itemCount} items', style: const TextStyle(fontSize: 9, color: Colors.black38)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
