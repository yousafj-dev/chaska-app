import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/models/chaska_comment.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';

/// Bottom sheet: reads/writes `chaska_videos/{id}/comments`.
class CommentsSheet extends StatefulWidget {
  final ChaskaVideo video;

  const CommentsSheet({super.key, required this.video});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirestoreService.instance.addComment(
        videoId: widget.video.id,
        text: text,
      );
      _ctrl.clear();
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.video.commentCount} comments',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: StreamBuilder<List<ChaskaComment>>(
                stream:
                    FirestoreService.instance.comments(widget.video.id),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'Abhi koi comment nahi.\nPehla comment tum karo!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accent.withOpacity(0.2),
                          child: Text(
                            c.username.isNotEmpty
                                ? c.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          c.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          c.text,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppTheme.accent, fontSize: 12)),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          hintText: 'Comment likho...',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.send,
                              color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
