import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/offline_service.dart';

/// "Offline videos": everything downloaded from the share sheet's
/// Download action. Tap to watch with no connection; the row's
/// menu deletes the local file.
class OfflineVideosScreen extends StatefulWidget {
  const OfflineVideosScreen({super.key});

  @override
  State<OfflineVideosScreen> createState() => _OfflineVideosScreenState();
}

class _OfflineVideosScreenState extends State<OfflineVideosScreen> {
  late Future<List<OfflineVideo>> _future;

  @override
  void initState() {
    super.initState();
    _future = OfflineService.instance.list();
  }

  void _reload() {
    setState(() => _future = OfflineService.instance.list());
  }

  Future<void> _delete(OfflineVideo entry) async {
    await OfflineService.instance.delete(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from offline videos')),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline videos')),
      body: FutureBuilder<List<OfflineVideo>>(
        future: _future,
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
                  'No offline videos yet.\nOpen any video, tap Share, then Download.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = videos[i];
              return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 68,
                        child: v.thumbUrl.isNotEmpty
                            ? Image.network(
                                v.thumbUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _ThumbFallback(),
                              )
                            : const _ThumbFallback(),
                      ),
                    ),
                    title: Text(
                      v.caption.isNotEmpty ? v.caption : 'Video',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    subtitle: Text(
                      '@${v.username}',
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 12),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white70),
                      color: AppTheme.card,
                      onSelected: (value) {
                        if (value == 'delete') _delete(v);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              OfflinePlayerScreen(entry: v),
                        ),
                      );
                    },
                  ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: const Icon(Icons.play_arrow, color: Colors.white54),
    );
  }
}

/// Full-screen player for one downloaded file (plays from local
/// storage, works fully offline).
class OfflinePlayerScreen extends StatefulWidget {
  final OfflineVideo entry;

  const OfflinePlayerScreen({super.key, required this.entry});

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.file(File(widget.entry.filePath));
    await c.initialize();
    await c.setLooping(true);
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _ctrl = c);
    c.play();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.entry.caption.isNotEmpty
              ? widget.entry.caption
              : 'Offline video',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: Center(
        child: c == null || !c.value.isInitialized
            ? const CircularProgressIndicator()
            : GestureDetector(
                onTap: () {
                  c.value.isPlaying ? c.pause() : c.play();
                  setState(() {});
                },
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
      ),
    );
  }
}
