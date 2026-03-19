import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import 'session_detail_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SessionProvider>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final sessions = sp.sessions;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(color: Colors.black87),
        title: const Text('Session History', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.black26),
                  SizedBox(height: 16),
                  Text('No sessions yet', style: TextStyle(color: Colors.black38, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Start a live interpretation to create a session', style: TextStyle(color: Colors.black26, fontSize: 14)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionCard(
                  session: session,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: session.id)),
                  ),
                  onDelete: () => _confirmDelete(context, session),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Session?', style: TextStyle(color: Colors.black87)),
        content: Text('This will permanently delete "${session.title}".', style: const TextStyle(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<SessionProvider>().deleteSession(session.id);
              Navigator.pop(c);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({required this.session, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dirLabel = session.direction == 'EN_ZH' ? 'EN → ZH' : 'ZH → EN';
    final date = '${session.startTime.month}/${session.startTime.day} ${session.startTime.hour}:${session.startTime.minute.toString().padLeft(2, '0')}';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic, color: Colors.blueAccent, size: 24),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(date, style: const TextStyle(fontSize: 12, color: Colors.black38)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(dirLabel, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 12),
                        Text('${session.items.length} items', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                        if (session.endTime != null) ...[
                          const SizedBox(width: 12),
                          Text(session.durationText, style: const TextStyle(fontSize: 12, color: Colors.black38)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black26, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
