import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/create/create_screen.dart';
import 'package:chaska/widgets/stories_row.dart';
import 'package:chaska/widgets/video_feed.dart';

/// MAIN screen: TikTok-style top tabs ("Following" | "For You"),
/// a stories row under the tabs, and a vertical swipe video feed.
///
/// Only the selected tab's feed is in the tree, so switching tabs
/// disposes the hidden feed's video controllers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _tabFollowing = 0;
  static const int _tabForYou = 1;
  int _tab = _tabForYou;

  @override
  Widget build(BuildContext context) {
    if (!AuthService.firebaseReady) {
      return _message(
        'Offline mode: videos will appear here once Firebase is set up.',
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _tab == _tabForYou ? _forYouFeed() : _followingFeed(),
        // Top overlay: scrim + tabs + stories row.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  _tabs(),
                  const SizedBox(height: 8),
                  const StoriesRow(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tabButton('Following', _tabFollowing),
        const SizedBox(width: 26),
        _tabButton('For You', _tabForYou),
      ],
    );
  }

  Widget _tabButton(String label, int tab) {
    final selected = _tab == tab;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              gradient:
                  selected ? AppTheme.primaryGradient : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forYouFeed() {
    return StreamBuilder<List<ChaskaVideo>>(
      stream: FirestoreService.instance.videoFeed(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _message('Could not load the feed. Please try again.');
        }
        final videos = snap.data ?? [];
        if (videos.isEmpty) return _emptyBody();
        return PagedVideoFeed(videos: videos);
      },
    );
  }

  Widget _followingFeed() {
    final myUid = AuthService.instance.uid;
    if (myUid == null) {
      return _iconMessage(
        Icons.people_outline,
        'Follow creators to see their videos here.',
      );
    }
    return StreamBuilder<List<String>>(
      stream: FirestoreService.instance.followingIds(myUid),
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ids = idsSnap.data ?? const <String>[];
        if (ids.isEmpty) {
          return _iconMessage(
            Icons.people_outline,
            'Follow creators to see their videos here.',
          );
        }
        return StreamBuilder<List<ChaskaVideo>>(
          stream: FirestoreService.instance.followingVideos(ids),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _message(
                  'Could not load the feed. Please try again.');
            }
            final videos = snap.data ?? [];
            if (videos.isEmpty) {
              return _iconMessage(
                Icons.video_library_outlined,
                'No videos yet from the people you follow.',
              );
            }
            return PagedVideoFeed(videos: videos);
          },
        );
      },
    );
  }

  Widget _emptyBody() {
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
                Icons.play_circle_outline,
                size: 44,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No videos yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload the first video!',
              style: TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Upload your first video'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconMessage(IconData icon, String text) {
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
              child: Icon(icon, size: 44, color: AppTheme.accent),
            ),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted, fontSize: 15),
        ),
      ),
    );
  }
}
