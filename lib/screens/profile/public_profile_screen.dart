import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/widgets/follow_button.dart';
import 'package:chaska/widgets/profile_stats_row.dart';
import 'package:chaska/widgets/video_feed.dart';

/// Public profile of any creator: avatar, name, bio, video grid
/// and a Follow/Unfollow button (hidden on your own profile).
/// Opened by tapping a video's avatar or @username in the feed.
class PublicProfileScreen extends StatelessWidget {
  final String uid;

  const PublicProfileScreen({super.key, required this.uid});

  bool get _isMe => uid == AuthService.instance.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Column(
        children: [
          const SizedBox(height: 20),
          StreamBuilder<ChaskaUser?>(
            stream: FirestoreService.instance.userProfile(uid),
            builder: (context, snap) => _header(context, snap.data),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          Expanded(child: _videosGrid(context)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ChaskaUser? profile) {
    final name = (profile != null && profile.displayName.isNotEmpty)
        ? profile.displayName
        : 'chaska_user';
    final photo = profile?.photoUrl ?? '';
    final bio = profile?.bio ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppTheme.accent.withOpacity(0.2),
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isNotEmpty
              ? null
              : Text(
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
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ProfileStatsRow(uid: uid),
        if (!_isMe) ...[
          const SizedBox(height: 14),
          FollowButton(targetUid: uid),
        ],
      ],
    );
  }

  Widget _videosGrid(BuildContext context) {
    return StreamBuilder<List<ChaskaVideo>>(
      stream: FirestoreService.instance.myVideos(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Could not load videos. Please try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          );
        }
        final videos = snap.data ?? [];
        if (videos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No videos yet.',
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
            return GestureDetector(
              onTap: () => _openVideo(context, videos, i),
              child: _thumbCell(v),
            );
          },
        );
      },
    );
  }

  Widget _thumbCell(ChaskaVideo v) {
    final thumb = v.thumbUrl;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumb.isNotEmpty)
            Image.network(
              thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.play_arrow,
                    color: Colors.white54, size: 36),
              ),
            )
          else
            const Center(
              child:
                  Icon(Icons.play_arrow, color: Colors.white54, size: 36),
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
  }

  void _openVideo(
      BuildContext context, List<ChaskaVideo> videos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PagedVideoFeed(videos: videos, initialPage: index),
        ),
      ),
    );
  }
}
