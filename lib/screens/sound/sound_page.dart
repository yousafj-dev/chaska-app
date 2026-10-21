import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/upload/upload_screen.dart';
import 'package:chaska/widgets/video_feed.dart';

/// Sound page: every video that uses one sound name, TikTok-style.
/// "Use this sound" opens the upload flow with the sound name
/// pre-attached, so the new video is grouped under the same sound.
/// (The new video keeps its own recorded audio — this groups and
/// attributes by sound name only.)
class SoundPage extends StatelessWidget {
  final String soundName;

  const SoundPage({super.key, required this.soundName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sound')),
      body: StreamBuilder<List<ChaskaVideo>>(
        stream: FirestoreService.instance.videosBySound(soundName),
        builder: (context, snap) {
          final videos = snap.data ?? [];
          final loading =
              snap.connectionState == ConnectionState.waiting;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, videos.length, loading),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : videos.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No videos use this sound yet.\nBe the first one!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.muted),
                              ),
                            ),
                          )
                        : _grid(context, videos),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, int count, bool loading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: const Icon(Icons.music_note,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      soundName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading
                          ? 'Loading...'
                          : '$count video${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UploadScreen(initialSoundName: soundName),
                ),
              );
            },
            icon: const Icon(Icons.music_note),
            label: const Text('Use this sound'),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<ChaskaVideo> videos) {
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
        final thumb = v.thumbUrl;
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    iconTheme:
                        const IconThemeData(color: Colors.white),
                  ),
                  body: PagedVideoFeed(videos: videos, initialPage: i),
                ),
              ),
            );
          },
          child: Container(
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
          ),
        );
      },
    );
  }
}
