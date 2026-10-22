import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/profile/public_profile_screen.dart';
import 'package:chaska/widgets/follow_button.dart';

enum UserListMode { following, followers }

/// User list behind a profile stat: the accounts [uid] follows,
/// or the accounts that follow [uid]. Each row resolves the user
/// doc for avatar + name, opens their public profile on tap, and
/// (for other people) carries a follow-state button.
class UserListScreen extends StatelessWidget {
  final String uid;
  final UserListMode mode;

  const UserListScreen({super.key, required this.uid, required this.mode});

  String get _title =>
      mode == UserListMode.following ? 'Following' : 'Followers';

  Stream<List<String>> get _idsStream => mode == UserListMode.following
      ? FirestoreService.instance.followingIds(uid)
      : FirestoreService.instance.followersIds(uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: StreamBuilder<List<String>>(
        stream: _idsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snap.data ?? const [];
          if (ids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  mode == UserListMode.following
                      ? 'Not following anyone yet.'
                      : 'No followers yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 1, indent: 76),
            itemBuilder: (context, i) => _row(context, ids[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String rowUid) {
    final isMe = rowUid == AuthService.instance.uid;
    return StreamBuilder<ChaskaUser?>(
      stream: FirestoreService.instance.userProfile(rowUid),
      builder: (context, snap) {
        final profile = snap.data;
        final name = (profile != null && profile.displayName.isNotEmpty)
            ? profile.displayName
            : 'chaska_user';
        final photo = profile?.photoUrl ?? '';
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.accent.withOpacity(0.2),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isNotEmpty
                ? null
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accent,
                    ),
                  ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '@$name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
          trailing: isMe
              ? null
              : FollowButton(targetUid: rowUid, compact: true),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PublicProfileScreen(uid: rowUid),
              ),
            );
          },
        );
      },
    );
  }
}
