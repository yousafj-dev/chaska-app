import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
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
        _statsRow(),
        if (!_isMe) ...[
          const SizedBox(height: 14),
          _followButton(context),
        ],
      ],
    );
  }

  Widget _statsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<List<ChaskaVideo>>(
          stream: FirestoreService.instance.myVideos(uid),
          builder: (context, snap) =>
              _stat('${snap.data?.length ?? 0}', 'Videos'),
        ),
        const SizedBox(width: 36),
        StreamBuilder<int>(
          stream: FirestoreService.instance.followingCount(uid),
          builder: (context, snap) =>
              _stat('${snap.data ?? 0}', 'Following'),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
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
    );
  }

  Widget _followButton(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FirestoreService.instance.isFollowing(uid),
      builder: (context, snap) {
        final following = snap.data ?? false;
        return GestureDetector(
          onTap: () async {
            try {
              await FirestoreService.instance
                  .setFollowing(uid, !following);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 42, vertical: 11),
            decoration: BoxDecoration(
              gradient: following ? null : AppTheme.primaryGradient,
              color: following ? AppTheme.card : null,
              border: following
                  ? Border.all(color: Colors.white24)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              following ? 'Following' : 'Follow',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
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
