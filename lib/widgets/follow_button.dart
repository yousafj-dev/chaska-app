import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';

/// Follow button with TikTok's three states:
/// - I don't follow them → "Follow" (or "Follow back" when they
///   already follow me)
/// - I follow them → "Following" (tap unfollows)
///
/// Used on public profile headers ([compact] = false) and in the
/// followers/following lists ([compact] = true). Renders nothing
/// on your own row/profile.
class FollowButton extends StatelessWidget {
  final String targetUid;
  final bool compact;

  const FollowButton({
    super.key,
    required this.targetUid,
    this.compact = false,
  });

  Future<void> _set(BuildContext context, bool follow) async {
    try {
      await FirestoreService.instance.setFollowing(targetUid, follow);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.uid;
    if (myUid == null || myUid == targetUid) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<bool>(
      stream: FirestoreService.instance.isFollowing(targetUid),
      builder: (context, snap) {
        final iFollow = snap.data ?? false;
        if (iFollow) {
          return _button(
            label: 'Following',
            filled: false,
            onTap: () => _set(context, false),
          );
        }
        return StreamBuilder<bool>(
          stream: FirestoreService.instance.followsMe(targetUid),
          builder: (context, backSnap) {
            final theyFollowMe = backSnap.data ?? false;
            return _button(
              label: theyFollowMe ? 'Follow back' : 'Follow',
              filled: true,
              onTap: () => _set(context, true),
            );
          },
        );
      },
    );
  }

  Widget _button({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 42, vertical: 11),
        decoration: BoxDecoration(
          gradient: filled ? AppTheme.primaryGradient : null,
          color: filled ? null : AppTheme.card,
          border: filled ? null : Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 12.5 : 14,
          ),
        ),
      ),
    );
  }
}
