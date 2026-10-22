import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/profile/user_list_screen.dart';

/// TikTok-style stats row for profiles (own + public):
/// **Following** and **Followers** are tappable and open the
/// matching user list; **Likes** is the summed like count across
/// all of the user's videos.
class ProfileStatsRow extends StatelessWidget {
  final String uid;

  const ProfileStatsRow({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<int>(
          stream: FirestoreService.instance.followingCount(uid),
          builder: (context, snap) => _stat(
            context,
            '${snap.data ?? 0}',
            'Following',
            () => _openList(context, UserListMode.following),
          ),
        ),
        const SizedBox(width: 36),
        StreamBuilder<int>(
          stream: FirestoreService.instance.followersCount(uid),
          builder: (context, snap) => _stat(
            context,
            '${snap.data ?? 0}',
            'Followers',
            () => _openList(context, UserListMode.followers),
          ),
        ),
        const SizedBox(width: 36),
        StreamBuilder<int>(
          stream: FirestoreService.instance.likesTotal(uid),
          builder: (context, snap) =>
              _stat(context, '${snap.data ?? 0}', 'Likes', null),
        ),
      ],
    );
  }

  void _openList(BuildContext context, UserListMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserListScreen(uid: uid, mode: mode),
      ),
    );
  }

  Widget _stat(
      BuildContext context, String value, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
