import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../painters/note_painter.dart';
import '../providers/note_provider.dart';

/// The drawing canvas widget. Captures pointer gestures and paints strokes.
class NoteCanvas extends StatelessWidget {
  const NoteCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NoteProvider>();

    return ClipRect(
      child: Consumer<NoteProvider>(
        builder: (context, note, _) {
          return GestureDetector(
            onPanStart: (details) {
              provider.startStroke(details.localPosition);
            },
            onPanUpdate: (details) {
              provider.addPoint(details.localPosition);
            },
            onPanEnd: (_) {
              provider.endStroke();
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: NotePainter(
                  strokes: note.strokes,
                  activeStroke: note.activeStroke,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );
  }
}
