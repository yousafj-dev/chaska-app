import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/widgets/video_card.dart';
import 'package:chaska/screens/upload/upload_screen.dart';

/// MAIN screen: vertical swipe feed of short videos (TikTok style).
/// Shows a friendly empty state when no videos exist yet.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.firebaseReady) {
      return _offlineBody();
    }
    return StreamBuilder<List<ChaskaVideo>>(
      stream: FirestoreService.instance.videoFeed(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _message('Feed load nahi ho saki. Dobara try karo.');
        }
        final videos = snap.data ?? [];
        if (videos.isEmpty) return _emptyBody();
        if (_current >= videos.length) _current = 0;
        return PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          itemCount: videos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (context, i) => VideoCard(
            video: videos[i],
            // Only the visible page plays; others stay paused.
            autoplay: i == _current,
            // Force rebuild of the player when the video changes.
            key: ValueKey('video_${videos[i].id}_$i'),
          ),
        );
      },
    );
  }

  Widget _offlineBody() {
    return _message(
      'Offline mode: Firebase setup ke baad yahan videos ayengi.',
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
              'Abhi koi video nahi hai',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pehli video tum upload karo!',
              style: TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const UploadScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Pehli video upload karo'),
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
