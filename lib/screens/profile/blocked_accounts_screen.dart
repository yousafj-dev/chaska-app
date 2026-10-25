import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/profile/public_profile_screen.dart';

/// Blocked accounts (Settings → Privacy): everyone I have
/// blocked, with an Unblock button each. Blocking is stored in
/// users/{me}/blocked and the feeds filter these authors out.
class BlockedAccountsScreen extends StatelessWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: myUid == null || !AuthService.firebaseReady
          ? const Center(
              child: Text(
                'Log in to see your blocked accounts.',
                style: TextStyle(color: AppTheme.muted),
              ),
            )
          : StreamBuilder<List<String>>(
              stream: FirestoreService.instance.blockedIds(myUid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final ids = snap.data ?? const [];
                if (ids.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'You have not blocked anyone.\n'
                        'To block someone, open their profile and '
                        'use the menu at the top right.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: ids.length,
                  separatorBuilder: (_, __) => const Divider(
                      color: Colors.white10, height: 1, indent: 76),
                  itemBuilder: (context, i) => _row(context, ids[i]),
                );
              },
            ),
    );
  }

  Widget _row(BuildContext context, String rowUid) {
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
          trailing: OutlinedButton(
            onPressed: () async {
              try {
                await FirestoreService.instance
                    .setBlocked(rowUid, false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unblocked @$name')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e
                            .toString()
                            .replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text('Unblock', style: TextStyle(fontSize: 12.5)),
          ),
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
