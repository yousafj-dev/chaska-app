import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/widgets/comments_sheet.dart';

/// One full-screen video page in the feed: autoplaying video,
/// double-tap to like, right-side action column, bottom caption.
class VideoCard extends StatefulWidget {
  final ChaskaVideo video;
  final bool autoplay;

  const VideoCard({
    super.key,
    required this.video,
    required this.autoplay,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _showHeart = false;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(VideoCard old) {
    super.didUpdateWidget(old);
    if (old.autoplay != widget.autoplay) _applyPlayState();
  }

  Future<void> _init() async {
    final url = widget.video.videoUrl;
    if (url.isEmpty) return;
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _ctrl = c;
        _ready = true;
      });
      _applyPlayState();
    } catch (e) {
      debugPrint('VideoCard init failed: $e');
    }
  }

  void _applyPlayState() {
    final c = _ctrl;
    if (c == null || !_ready) return;
    if (widget.autoplay) {
      c.play();
    } else {
      c.pause();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _onDoubleTap() async {
    if (_liking) return;
    setState(() {
      _showHeart = true;
      _liking = true;
    });
    try {
      final auth = AuthService.instance;
      if (!AuthService.firebaseReady || !auth.isSignedIn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Like ke liye pehle login karo.')),
          );
        }
        return;
      }
      final nowLiked = await FirestoreService.instance.toggleLike(widget.video);
      if (nowLiked && mounted) {
        // Feed refreshes via stream; heart pop is instant feedback.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _liking = false);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _showHeart = false);
        });
      }
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(video: widget.video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.uid;
    final liked = widget.video.likedByMe(myUid);
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      onTap: () {
        final c = _ctrl;
        if (c == null || !_ready) return;
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (_ready && _ctrl != null)
            Center(child: AspectRatio(
              aspectRatio: _ctrl!.value.aspectRatio,
              child: VideoPlayer(_ctrl!),
            ))
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          // Double-tap heart pop
          if (_showHeart)
            const Center(
              child: Icon(Icons.favorite,
                  size: 110, color: AppTheme.accent),
            ),
          // Right-side action column
          Positioned(
            right: 10,
            bottom: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? AppTheme.accent : Colors.white,
                  label: _shortNum(widget.video.likes),
                  onTap: _onDoubleTap,
                ),
                const SizedBox(height: 18),
                _actionBtn(
                  icon: Icons.comment_outlined,
                  color: Colors.white,
                  label: _shortNum(widget.video.commentCount),
                  onTap: _openComments,
                ),
                const SizedBox(height: 18),
                _actionBtn(
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: 'Share',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Share jald aa raha hai.')),
                    );
                  },
                ),
              ],
            ),
          ),
          // Bottom caption + username
          Positioned(
            left: 14,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${widget.video.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (widget.video.caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.video.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _shortNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
