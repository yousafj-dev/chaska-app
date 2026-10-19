import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/auth/auth_screen.dart';

/// Profile: avatar, username, my videos grid, logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final name = auth.displayName;
    return Scaffold(
      appBar: AppBar(
        title: Text('@$name'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 44,
            backgroundColor: AppTheme.accent.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '@$name',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Meri videos',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          Expanded(child: _myVideosGrid(auth)),
        ],
      ),
    );
  }

  Widget _myVideosGrid(AuthService auth) {
    final uid = auth.uid;
    if (!AuthService.firebaseReady || uid == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Login ke baad tumhari videos yahan dikhengi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }
    return StreamBuilder<List<ChaskaVideo>>(
      stream: FirestoreService.instance.myVideos(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final videos = snap.data ?? [];
        if (videos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Abhi koi video upload nahi ki.\nNeeche + dabao aur pehli video banao!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.7,
          ),
          itemCount: videos.length,
          itemBuilder: (context, i) {
            final v = videos[i];
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Center(
                    child: Icon(Icons.play_arrow,
                        color: Colors.white54, size: 36),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text(
                          '${v.likes}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
