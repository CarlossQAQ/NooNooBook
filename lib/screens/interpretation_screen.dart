import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/interpretation_provider.dart';
import '../providers/session_provider.dart';
import 'session_detail_screen.dart';

class InterpretationScreen extends StatefulWidget {
  const InterpretationScreen({super.key});

  @override
  State<InterpretationScreen> createState() => _InterpretationScreenState();
}

class _InterpretationScreenState extends State<InterpretationScreen> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<SessionProvider>().ensureLoaded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<InterpretationProvider>();
    final sp = context.watch<SessionProvider>();

    _scrollToBottom();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Row(
        children: [
          // ── 左侧 Sidebar ──
          _SessionSidebar(
            sessions: sp.sessions,
            isRecording: ai.isRecording,
            viewingSessionId: ai.viewingSession?.id,
            onNewSession: () => ai.newSession(),
            onSelectSession: (session) => ai.viewSession(session),
            onDeleteSession: (id) => sp.deleteSession(id),
            onViewDetail: (session) => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: session.id)),
            ),
          ),

          // ── 右侧内容区 ──
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      const BackButton(color: Colors.black87),
                      const Text('Live Interpreter', style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ai.direction,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                          icon: const Icon(Icons.swap_horiz, color: Colors.black54),
                          items: const [
                            DropdownMenuItem(value: 'EN_ZH', child: Text('English → Chinese')),
                            DropdownMenuItem(value: 'ZH_EN', child: Text('Chinese → English')),
                          ],
                          onChanged: ai.isRecording ? null : (val) {
                            if (val != null) context.read<InterpretationProvider>().setDirection(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtitle area
                Expanded(
                  child: ai.subtitleItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_none, size: 64, color: Colors.black.withValues(alpha: 0.12)),
                              const SizedBox(height: 16),
                              Text(
                                ai.isViewingHistory ? 'Empty session' : 'Tap Start to begin interpreting',
                                style: const TextStyle(color: Colors.black38, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          itemCount: ai.subtitleItems.length,
                          itemBuilder: (context, index) {
                            return _SubtitleBlock(item: ai.subtitleItems[index]);
                          },
                        ),
                ),

                // Bottom control panel
                if (!ai.isViewingHistory)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.summarize),
                          label: const Text('AI Summarize'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: (!ai.isRecording && ai.subtitleItems.isNotEmpty)
                              ? () => _showSummary(context)
                              : null,
                        ),
                        FloatingActionButton.extended(
                          backgroundColor: ai.isRecording ? Colors.redAccent : Colors.black87,
                          onPressed: () => context.read<InterpretationProvider>().toggleRecording(),
                          icon: Icon(ai.isRecording ? Icons.stop : Icons.mic, color: Colors.white),
                          label: Text(
                            ai.isRecording ? 'Stop' : 'Start Translating',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSummary(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        backgroundColor: Colors.white,
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text("Generating AI Summary...", style: TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );

    final summary = await context.read<InterpretationProvider>().generateSummary();
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('AI Summary', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: _StructuredSummaryContent(summary: summary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }
}

// ──────────── Sidebar ────────────

class _SessionSidebar extends StatelessWidget {
  final List sessions;
  final bool isRecording;
  final String? viewingSessionId;
  final VoidCallback onNewSession;
  final Function(dynamic) onSelectSession;
  final Function(String) onDeleteSession;
  final Function(dynamic) onViewDetail;

  const _SessionSidebar({
    required this.sessions,
    required this.isRecording,
    required this.viewingSessionId,
    required this.onNewSession,
    required this.onSelectSession,
    required this.onDeleteSession,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F3),
        border: Border(right: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          // New Session button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.black12),
                  ),
                ),
                onPressed: isRecording ? null : onNewSession,
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.black38),
                SizedBox(width: 6),
                Text('History', style: TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Session list
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Text('No sessions yet', style: TextStyle(color: Colors.black26, fontSize: 13)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = session.id == viewingSessionId;
                      return _SidebarSessionTile(
                        session: session,
                        isActive: isActive,
                        isEnabled: !isRecording,
                        onTap: () => onSelectSession(session),
                        onDelete: () => onDeleteSession(session.id),
                        onViewDetail: () => onViewDetail(session),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSessionTile extends StatelessWidget {
  final dynamic session;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onViewDetail;

  const _SidebarSessionTile({
    required this.session,
    required this.isActive,
    required this.isEnabled,
    required this.onTap,
    required this.onDelete,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final date = '${session.startTime.month}/${session.startTime.day} ${session.startTime.hour}:${session.startTime.minute.toString().padLeft(2, '0')}';
    final dirLabel = session.direction == 'EN_ZH' ? 'EN→ZH' : 'ZH→EN';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isEnabled ? Colors.black87 : Colors.black38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$date  $dirLabel  ${session.items.length} items',
                        style: const TextStyle(fontSize: 11, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
                if (isActive) ...[
                  InkWell(
                    onTap: onViewDetail,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.open_in_new, size: 14, color: Colors.black38),
                    ),
                  ),
                  InkWell(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 14, color: Colors.black26),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────── Subtitle Block ────────────

class _SubtitleBlock extends StatelessWidget {
  final SubtitleItem item;
  const _SubtitleBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPending = !item.isFinalized;
    final hasTranslation = item.translatedText.isNotEmpty && item.translatedText != '翻译中...';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPending ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 源文本（打字效果：未完成行带闪烁光标）
          Row(
            children: [
              Expanded(
                child: Text(
                  item.sourceText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isPending ? Colors.black87 : Colors.black54,
                    fontWeight: isPending ? FontWeight.w500 : FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
              if (isPending)
                const _BlinkingCursor(),
            ],
          ),

          // 翻译部分（只有句子完成后才显示）
          if (item.isFinalized) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 8),
            if (item.translatedText == '翻译中...')
              Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(width: 8),
                  const Text('翻译中...', style: TextStyle(fontSize: 14, color: Colors.black38, fontStyle: FontStyle.italic)),
                ],
              )
            else if (hasTranslation)
              Text(
                item.translatedText,
                style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4),
              ),
          ],
        ],
      ),
    );
  }
}

/// 闪烁光标
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: 2,
          height: 18,
          margin: const EdgeInsets.only(left: 2),
          color: Colors.blueAccent.withValues(alpha: _controller.value),
        );
      },
    );
  }
}

// ──────────── Structured Summary ────────────

class _StructuredSummaryContent extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _StructuredSummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    final topic = summary['topic'] as String? ?? '';
    final keyPoints = _toStringList(summary['key_points']);
    final actionItems = _toStringList(summary['action_items']);
    final decisions = _toStringList(summary['decisions']);
    final briefSummary = summary['brief_summary'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topic.isNotEmpty) ...[
          _SectionHeader(icon: Icons.topic, title: 'Topic'),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(topic, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
          ),
        ],
        if (briefSummary.isNotEmpty) ...[
          _SectionHeader(icon: Icons.description, title: 'Summary'),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(briefSummary, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
          ),
        ],
        if (keyPoints.isNotEmpty) ...[
          _SectionHeader(icon: Icons.lightbulb_outline, title: 'Key Points'),
          ...keyPoints.map((p) => _BulletItem(text: p, color: Colors.blueAccent)),
          const SizedBox(height: 12),
        ],
        if (actionItems.isNotEmpty) ...[
          _SectionHeader(icon: Icons.check_circle_outline, title: 'Action Items'),
          ...actionItems.map((p) => _BulletItem(text: p, color: Colors.green)),
          const SizedBox(height: 12),
        ],
        if (decisions.isNotEmpty) ...[
          _SectionHeader(icon: Icons.gavel, title: 'Decisions'),
          ...decisions.map((p) => _BulletItem(text: p, color: Colors.orange)),
        ],
      ],
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    return [];
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4))),
        ],
      ),
    );
  }
}
