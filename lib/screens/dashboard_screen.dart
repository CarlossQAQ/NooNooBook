import 'package:flutter/material.dart';
import 'bookshelf_screen.dart';
import 'interpretation_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SimulNote', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DashboardCard(
                icon: Icons.menu_book_rounded,
                title: 'My Notebooks',
                subtitle: 'PDF Bookshelf & Annotations',
                color: const Color(0xFF8B7355),
                cardBg: cardBg, textColor: textColor, subColor: subColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookshelfScreen())),
              ),
              const SizedBox(width: 48),
              _DashboardCard(
                icon: Icons.record_voice_over,
                title: 'Live Interpreter',
                subtitle: 'AI Simultaneous Translation',
                color: Colors.deepPurpleAccent,
                cardBg: cardBg, textColor: textColor, subColor: subColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterpretationScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color cardBg;
  final Color textColor;
  final Color subColor;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap,
    required this.cardBg, required this.textColor, required this.subColor,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          height: 320,
          transform: _hovering ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _hovering ? widget.color.withValues(alpha: 0.4) : Colors.black12),
            boxShadow: [
              BoxShadow(
                color: _hovering ? widget.color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                blurRadius: _hovering ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(widget.icon, size: 56, color: widget.color),
              ),
              const SizedBox(height: 28),
              Text(widget.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: widget.textColor)),
              const SizedBox(height: 10),
              Text(widget.subtitle, style: TextStyle(fontSize: 14, color: widget.subColor)),
            ],
          ),
        ),
      ),
    );
  }
}
