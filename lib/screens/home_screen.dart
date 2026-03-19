import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import 'note_canvas.dart';

/// The split screen layout: left PDF placeholder | right drawing panel.
class NotebookScreen extends StatelessWidget {
  const NotebookScreen({super.key});

  // Palette of selectable colors
  static const _palette = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Color(0xFFFF9800), // orange
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // ── Left: PDF panel stub ──────────────────────────────────────
          Expanded(
            flex: 42,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        size: 64, color: Colors.black26),
                    SizedBox(height: 16),
                    Text(
                      'PDF Panel',
                      style: TextStyle(
                          color: Colors.black54,
                          fontSize: 20,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Phase 2 Integration',
                      style: TextStyle(color: Colors.black38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Right: toolbar + canvas ───────────────────────────────────
          Expanded(
            flex: 58,
            child: Column(
              children: [
                _Toolbar(palette: _palette),
                Expanded(
                  child: Container(
                    margin:
                        const EdgeInsets.only(right: 12, bottom: 12, top: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      // Faint dot grid could be added here later, for now plain white
                      child: const NoteCanvas(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toolbar ─────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final List<Color> palette;
  const _Toolbar({required this.palette});

  @override
  Widget build(BuildContext context) {
    final note = context.watch<NoteProvider>();

    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Navigation Back
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),

          // Color swatches
          ...palette.map((color) => _ColorDot(
                color: color,
                isSelected: !note.isEraser && note.currentColor == color,
                onTap: () => context.read<NoteProvider>().setColor(color),
              )),

          const SizedBox(width: 12),
          _ToolbarDivider(),

          // Eraser button (now deletes strokes)
          _ToolBtn(
            icon: Icons.auto_fix_normal, // or some eraser icon
            label: 'Object Eraser',
            active: note.isEraser,
            onTap: () => context.read<NoteProvider>().toggleEraser(),
          ),

          const SizedBox(width: 4),
          _ToolbarDivider(),

          // Size slider
          const Icon(Icons.edit, color: Colors.black54, size: 18),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Colors.black12,
                thumbColor: Colors.white,
                trackHeight: 4,
              ),
              child: Slider(
                value: note.currentSize,
                min: 3,
                max: 24,
                onChanged: (v) => context.read<NoteProvider>().setSize(v),
              ),
            ),
          ),

          _ToolbarDivider(),

          // Undo
          _ToolBtn(
            icon: Icons.undo,
            label: 'Undo',
            active: false,
            onTap: () => context.read<NoteProvider>().undo(),
          ),

          // Clear
          _ToolBtn(
            icon: Icons.delete_outline,
            label: 'Clear',
            active: false,
            onTap: () => _confirmClear(context),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Clear Canvas',
            style: TextStyle(color: Colors.black87)),
        content: const Text('Delete all strokes?',
            style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              context.read<NoteProvider>().clearPage();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorDot(
      {required this.color,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 34 : 26,
        height: isSelected ? 34 : 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black26 : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const _ToolBtn(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap,
      this.activeColor});

  @override
  Widget build(BuildContext context) {
    final themeColor = activeColor ?? Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? themeColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: active ? themeColor : Colors.black54, size: 24),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.black12,
    );
  }
}

