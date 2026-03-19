import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/session.dart';
import '../providers/session_provider.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isSummarizing = false;

  Session? _findSession(SessionProvider sp) {
    try {
      return sp.sessions.firstWhere((s) => s.id == widget.sessionId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final session = _findSession(sp);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Not Found')),
        body: const Center(child: Text('This session has been deleted.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(color: Colors.black87),
        title: Text(session.title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isSummarizing)
            TextButton.icon(
              icon: const Icon(Icons.summarize, size: 18),
              label: const Text('AI Summary'),
              onPressed: session.items.isNotEmpty ? () => _generateSummary(session) : null,
            ),
          if (_isSummarizing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Session info bar
          _SessionInfoBar(session: session),
          const SizedBox(height: 16),

          // Summary (if available)
          if (session.summary != null) ...[
            _SummaryCard(summary: session.summary!),
            const SizedBox(height: 16),
          ],

          // Transcript items
          ...session.items.map((item) => _TranscriptCard(item: item)),
        ],
      ),
    );
  }

  Future<void> _generateSummary(Session session) async {
    setState(() => _isSummarizing = true);

    try {
      final text = session.items.map((i) => i.sourceText).join(' ');
      final uri = Uri.parse('http://localhost:8000/summarize');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['summary'];
        if (summary is Map<String, dynamic> && mounted) {
          await context.read<SessionProvider>().updateSessionSummary(session.id, summary);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Summary failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _isSummarizing = false);
  }
}

class _SessionInfoBar extends StatelessWidget {
  final Session session;
  const _SessionInfoBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final dirLabel = session.direction == 'EN_ZH' ? 'English → Chinese' : 'Chinese → English';
    final date = '${session.startTime.year}/${session.startTime.month}/${session.startTime.day} ${session.startTime.hour}:${session.startTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.black38),
          const SizedBox(width: 8),
          Text(date, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(width: 16),
          Text(dirLabel, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(width: 16),
          Text('${session.items.length} items', style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (session.endTime != null) ...[
            const SizedBox(width: 16),
            Text(session.durationText, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final topic = summary['topic'] as String? ?? '';
    final keyPoints = _toList(summary['key_points']);
    final actionItems = _toList(summary['action_items']);
    final decisions = _toList(summary['decisions']);
    final brief = summary['brief_summary'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Colors.blueAccent),
              SizedBox(width: 6),
              Text('AI Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
            ],
          ),
          if (topic.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(topic, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
          if (brief.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(brief, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
          ],
          if (keyPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Key Points', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black45)),
            const SizedBox(height: 4),
            ...keyPoints.map((p) => Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: Colors.blueAccent)),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4))),
                ],
              ),
            )),
          ],
          if (actionItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Action Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black45)),
            const SizedBox(height: 4),
            ...actionItems.map((p) => Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4))),
                ],
              ),
            )),
          ],
          if (decisions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Decisions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black45)),
            const SizedBox(height: 4),
            ...decisions.map((p) => Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: Colors.orange)),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  List<String> _toList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    return [];
  }
}

class _TranscriptCard extends StatelessWidget {
  final SubtitleItemData item;
  const _TranscriptCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.sourceText, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.4)),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 6),
          Text(item.translatedText, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4)),
        ],
      ),
    );
  }
}
