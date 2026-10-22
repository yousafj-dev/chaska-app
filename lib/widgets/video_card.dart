import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/profile/public_profile_screen.dart';
import 'package:chaska/screens/sound/sound_page.dart';
import 'package:chaska/widgets/comments_sheet.dart';
import 'package:chaska/widgets/share_sheet.dart';

/// One full-screen video page in the feed: autoplaying video,
/// double-tap to like, right-side action column, bottom caption.
///
/// Player lifecycle (feed-paging fix): the controller is bound to
/// this card's video id. It is created when the page becomes the
/// active page, re-created if the widget is ever re-bound to a
/// different video, paused when the page stops being active, and
/// disposed with the widget. An async init that finishes after the
/// card moved on to another video is discarded, so a stale player
/// can never bleed into the wrong page.
/// Playback-only URL for the feed player. Cloudinary uploads are
/// streamed through a lightweight delivery variant (auto low
/// quality, max 720 wide, auto codec) so playback STARTS fast —
/// the original file can be several times larger. Everything else
/// (downloads, offline, sharing) keeps using the original URL.
String playbackUrlFor(String url) {
  if (!url.contains('/upload/')) return url;
  return url.replaceFirst(
      '/upload/', '/upload/q_auto:low,w_720,c_limit,vc_auto/');
}

class VideoCard extends StatefulWidget {
  final ChaskaVideo video;
  final bool isActive;

  /// True for the page right after the active one: its player is
  /// initialized (not played) so a swipe starts instantly.
  final bool preload;

  const VideoCard({
    super.key,
    required this.video,
    required this.isActive,
    this.preload = false,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? _ctrl;

  /// The video id [_ctrl] (or the in-flight init) belongs to.
  String? _boundId;
  bool _initializing = false;
  bool _showHeart = false;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _ensurePlayer();
      // Watch history (Activity center): one write per video per
      // app session, throttled inside the service.
      FirestoreService.instance.recordWatch(widget.video.id);
    } else if (widget.preload) {
      // Next page: warm the player up (never plays from here —
      // _ensurePlayer only plays when this card is active).
      _ensurePlayer();
    }
  }

  @override
  void didUpdateWidget(VideoCard old) {
    super.didUpdateWidget(old);
    if (old.video.id != widget.video.id) {
      // Re-bound to a different video: drop the old player entirely.
      _teardownPlayer();
      if (widget.isActive) {
        _ensurePlayer();
        FirestoreService.instance.recordWatch(widget.video.id);
      } else if (widget.preload) {
        _ensurePlayer();
      }
      return;
    }
    if (old.isActive != widget.isActive) {
      if (widget.isActive) {
        _ensurePlayer();
        FirestoreService.instance.recordWatch(widget.video.id);
        _ctrl?.play();
      } else {
        _ctrl?.pause();
      }
      return;
    }
    if (!old.preload && widget.preload && !widget.isActive) {
      _ensurePlayer();
    }
  }

  Future<void> _ensurePlayer() async {
    if (_boundId == widget.video.id && (_ctrl != null || _initializing)) {
      return;
    }
    final rawUrl = widget.video.videoUrl;
    if (rawUrl.isEmpty) return;
    final url = playbackUrlFor(rawUrl);
    final id = widget.video.id;
    _boundId = id;
    _initializing = true;
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      await c.setLooping(true);
      if (!mounted || _boundId != id) {
        // The card moved on while this was loading — discard it.
        c.dispose();
        return;
      }
      setState(() => _ctrl = c);
      if (widget.isActive) c.play();
    } catch (e) {
      debugPrint('VideoCard init failed: $e');
      if (_boundId == id) _boundId = null;
    } finally {
      if (_boundId == id) _initializing = false;
    }
  }

  void _teardownPlayer() {
    _ctrl?.dispose();
    _ctrl = null;
    _boundId = null;
    _initializing = false;
  }

  @override
  void dispose() {
    _teardownPlayer();
    super.dispose();
  }

  bool get _ready => _ctrl != null && _ctrl!.value.isInitialized;

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
            const SnackBar(
                content: Text('Please log in first to like.')),
          );
        }
        return;
      }
      await FirestoreService.instance.toggleLike(widget.video);
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

  bool _requireLogin() {
    final auth = AuthService.instance;
    if (AuthService.firebaseReady && auth.isSignedIn) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first.')),
    );
    return false;
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showErr(Object e) {
    _showMsg(e.toString().replaceFirst('Exception: ', ''));
  }

  void _openSoundPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SoundPage(soundName: widget.video.soundName),
      ),
    );
  }

  /// TikTok-style: the rail Share button opens the "Share to"
  /// sheet (Repost / Favorite / Download / Copy link / Share /
  /// Not interested / Report all live there now).
  void _openShareSheet() {
    showShareSheet(context, widget.video);
  }

  void _openAuthorProfile() {
    final uid = widget.video.uid;
    if (uid.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(uid: uid),
      ),
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
          if (_ready)
            Center(
              child: AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio,
                child: VideoPlayer(_ctrl!),
              ),
            )
          else
            _placeholder(),
          // Double-tap heart pop
          if (_showHeart)
            const Center(
              child: Icon(Icons.favorite,
                  size: 110, color: AppTheme.accent2),
            ),
          // Right-side action column: owner avatar + glass buttons
          Positioned(
            right: 8,
            bottom: 78,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ownerAvatar(),
                const SizedBox(height: 10),
                _GlassActionButton(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  iconColor: liked ? AppTheme.accent2 : Colors.white,
                  label: _shortNum(widget.video.likes),
                  popOnTap: true,
                  onTap: _onDoubleTap,
                ),
                const SizedBox(height: 10),
                _GlassActionButton(
                  icon: Icons.comment_outlined,
                  iconColor: Colors.white,
                  label: _shortNum(widget.video.commentCount),
                  onTap: _openComments,
                ),
                const SizedBox(height: 10),
                _GlassActionButton(
                  icon: Icons.share_outlined,
                  iconColor: Colors.white,
                  label: _shortNum(widget.video.shareCount),
                  onTap: _openShareSheet,
                ),
              ],
            ),
          ),
          // Bottom caption + username (tap name → creator profile)
          Positioned(
            left: 14,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _openAuthorProfile,
                  child: Text(
                    '@${widget.video.username}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
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
                const SizedBox(height: 8),
                // Sound row: tap → sound page with all videos
                // using this sound + "Use this sound".
                GestureDetector(
                  onTap: _openSoundPage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.video.soundName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Thumbnail + spinner shown while this page's player loads, so
  /// every page is visually distinct even before playback starts.
  Widget _placeholder() {
    final thumb = widget.video.thumbUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb.isNotEmpty)
          Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      ],
    );
  }

  /// Uploader avatar at the top of the rail (tap → creator
  /// profile), with a TikTok-style "+" badge to follow the creator
  /// right from the feed. The badge hides on your own videos and
  /// once you already follow the creator.
  /// Reads the live profile (photo + nickname) from `users/{uid}`,
  /// falling back to the username stored on the video.
  Widget _ownerAvatar() {
    final myUid = AuthService.instance.uid;
    final isMine = myUid != null && myUid == widget.video.uid;
    return StreamBuilder<ChaskaUser?>(
      stream: FirestoreService.instance.userProfile(widget.video.uid),
      builder: (context, snap) {
        final profile = snap.data;
        final photo = profile?.photoUrl ?? '';
        final name = (profile != null && profile.displayName.isNotEmpty)
            ? profile.displayName
            : widget.video.username;
        return SizedBox(
          width: 46,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              GestureDetector(
                onTap: _openAuthorProfile,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.card,
                    backgroundImage:
                        photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isNotEmpty
                        ? null
                        : Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
              if (!isMine)
                Positioned(
                  bottom: 0,
                  child: StreamBuilder<bool>(
                    stream: FirestoreService.instance
                        .isFollowing(widget.video.uid),
                    builder: (context, fSnap) {
                      if (fSnap.data ?? false) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () async {
                          if (!_requireLogin()) return;
                          try {
                            await FirestoreService.instance
                                .setFollowing(widget.video.uid, true);
                            if (mounted) {
                              _showMsg('Following @$name');
                            }
                          } catch (e) {
                            if (mounted) _showErr(e);
                          }
                        },
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accent2,
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 13),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _shortNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// One modern glass action button for the feed rail: circular dark
/// glass disc, white icon, bold count label underneath. With
/// [popOnTap] the icon does a quick scale "pop" when tapped.
class _GlassActionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool popOnTap;

  const _GlassActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.popOnTap = false,
  });

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.popOnTap) _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.45),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 24),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
