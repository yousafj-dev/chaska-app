import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_notification.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/profile/public_profile_screen.dart';

/// Inbox: my notifications (likes, comments, follows), newest
/// first. Opening the Inbox marks everything as read. The list is
/// filtered by my notification preferences (Settings →
/// Notifications) — a type whose toggle is off is not shown.
class InboxScreen extends StatefulWidget {
  /// Whether the Inbox bottom-nav tab is the selected one. The
  /// shell keeps tabs mounted, so "opening the Inbox" means this
  /// turning true — that is when notifications are marked read.
  final bool isVisible;

  const InboxScreen({super.key, this.isVisible = false});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isVisible) _markRead();
  }

  @override
  void didUpdateWidget(InboxScreen old) {
    super.didUpdateWidget(old);
    if (!old.isVisible && widget.isVisible) _markRead();
  }

  void _markRead() {
    // Viewing the Inbox clears the unread badge.
    FirestoreService.instance.markAllNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: !AuthService.firebaseReady
          ? _empty(
              'Notifications are unavailable right now.',
            )
          : StreamBuilder<ChaskaUser?>(
              stream: _myProfile(),
              builder: (context, profSnap) {
                final prefs = profSnap.data;
                return StreamBuilder<List<ChaskaNotification>>(
                  stream:
                      FirestoreService.instance.myNotifications(),
                  builder: (context, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? const [];
                    final items = all.where((n) {
                      switch (n.type) {
                        case 'like':
                          return prefs?.notifLikes ?? true;
                        case 'comment':
                          return prefs?.notifComments ?? true;
                        case 'follow':
                          return prefs?.notifFollows ?? true;
                        default:
                          return true;
                      }
                    }).toList();
                    if (items.isEmpty) return _emptyState();
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(
                          color: Colors.white10, height: 1, indent: 76),
                      itemBuilder: (context, i) => _row(items[i]),
                    );
                  },
                );
              },
            ),
    );
  }

  Stream<ChaskaUser?> _myProfile() {
    final uid = AuthService.instance.uid;
    if (uid == null) return Stream.value(null);
    return FirestoreService.instance.userProfile(uid);
  }

  Widget _row(ChaskaNotification n) {
    final icon = switch (n.type) {
      'like' => Icons.favorite,
      'comment' => Icons.comment,
      'follow' => Icons.person_add,
      _ => Icons.notifications,
    };
    final color = switch (n.type) {
      'like' => AppTheme.accent2,
      'comment' => AppTheme.accent,
      'follow' => AppTheme.accent,
      _ => AppTheme.muted,
    };
    final text = switch (n.type) {
      'like' => 'liked your video',
      'comment' =>
        n.text.isNotEmpty ? 'commented: ${n.text}' : 'commented on your video',
      'follow' => 'started following you',
      _ => 'interacted with you',
    };
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.card,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          if (!n.read)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.accent2,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        '@${n.fromName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
      ),
      trailing: Text(
        _timeAgo(n.createdAt),
        style: const TextStyle(color: AppTheme.muted, fontSize: 11),
      ),
      onTap: () {
        if (n.fromUid.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(uid: n.fromUid),
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM').format(t);
  }

  Widget _emptyState() {
    return _empty(
      'When someone likes or comments on your video, or follows you, it will show up here.',
      title: 'No notifications',
    );
  }

  Widget _empty(String message, {String? title}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                size: 44,
                color: AppTheme.muted,
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
