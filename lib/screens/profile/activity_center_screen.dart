import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/widgets/video_feed.dart';

/// Activity center: two grids — videos you liked, and your watch
/// history (recorded when a feed video becomes active, once per
/// video per app session). Tapping a tile opens the same
/// full-screen pager the profile uses.
class ActivityCenterScreen extends StatelessWidget {
  const ActivityCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity center'),
          bottom: const TabBar(
            indicatorColor: AppTheme.accent2,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.muted,
            labelStyle:
                TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            tabs: [
              Tab(icon: Icon(Icons.favorite_border, size: 20),
                  text: 'Liked'),
              Tab(icon: Icon(Icons.history, size: 20), text: 'History'),
            ],
          ),
        ),
        body: uid == null || !AuthService.firebaseReady
            ? const Center(
                child: Text(
                  'Log in to see your activity.',
                  style: TextStyle(color: AppTheme.muted),
                ),
              )
            : TabBarView(
                children: [
                  _grid(
                    context,
                    stream: FirestoreService.instance.likedVideos(uid),
                    emptyText:
                        'No liked videos yet.\nDouble-tap a video to like it.',
                  ),
                  _grid(
                    context,
                    stream: FirestoreService.instance.historyVideos(uid),
                    emptyText:
                        'Nothing watched yet.\nVideos you watch will show up here.',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _grid(
    BuildContext context, {
    required Stream<List<ChaskaVideo>> stream,
    required String emptyText,
  }) {
    return StreamBuilder<List<ChaskaVideo>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Could not load videos. Please try again later.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted),
              ),
            ),
          );
        }
        final videos = snap.data ?? [];
        if (videos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.7,
          ),
          itemCount: videos.length,
          itemBuilder: (context, i) {
            final v = videos[i];
            return GestureDetector(
              onTap: () => _openViewer(context, videos, i),
              child: _thumbCell(v),
            );
          },
        );
      },
    );
  }

  void _openViewer(
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
}
