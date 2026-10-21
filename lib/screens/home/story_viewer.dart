import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_story.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/widgets/story_actions.dart';

/// Full-screen story viewer: segmented progress bars on top,
/// tap right = next, tap left = previous, images advance after
/// 5 seconds, videos advance when they end, swipe down or X closes.
class StoryViewer extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialGroup;

  const StoryViewer({
    super.key,
    required this.groups,
    required this.initialGroup,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  static const _imageDuration = Duration(seconds: 5);

  late int _g;
  int _i = 0;
  VideoPlayerController? _ctrl;
  Timer? _ticker;
  double _progress = 0;
  int _token = 0;
  DateTime _shownAt = DateTime.now();

  StoryGroup get _group => widget.groups[_g];
  ChaskaStory get _story => _group.stories[_i];
  bool get _isMine => _group.uid == AuthService.instance.uid;

  @override
  void initState() {
    super.initState();
    _g = widget.initialGroup.clamp(0, widget.groups.length - 1);
    _show();
  }

  @override
  void dispose() {
    _token++;
    _ticker?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  void _show() {
    final token = ++_token;
    _ticker?.cancel();
    _ctrl?.dispose();
    _ctrl = null;
    _progress = 0;
    _shownAt = DateTime.now();
    final story = _story;
    StoryViews.markViewed(story.id);
    if (story.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
      _ctrl = c;
      c.initialize().then((_) {
        if (!mounted || token != _token) {
          c.dispose();
          return;
        }
        c.play();
        setState(() {});
      }).catchError((e) {
        debugPrint('Story video failed: $e');
        if (mounted && token == _token) _next();
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || token != _token) return;
        final cc = _ctrl;
        if (cc == null || !cc.value.isInitialized) return;
        final dur = cc.value.duration.inMilliseconds;
        if (dur <= 0) return;
        final pos = cc.value.position.inMilliseconds;
        if (pos >= dur - 120) {
          _next();
        } else {
          setState(() => _progress = (pos / dur).clamp(0.0, 1.0));
        }
      });
    } else {
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || token != _token) return;
        final elapsed = DateTime.now().difference(_shownAt);
        final p = elapsed.inMilliseconds / _imageDuration.inMilliseconds;
        if (p >= 1) {
          _next();
        } else {
          setState(() => _progress = p);
        }
      });
    }
  }

  void _next() {
    if (_i < _group.stories.length - 1) {
      setState(() => _i++);
    } else if (_g < widget.groups.length - 1) {
      setState(() {
        _g++;
        _i = 0;
      });
    } else {
      Navigator.of(context).pop();
      return;
    }
    _show();
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
    } else if (_g > 0) {
      setState(() {
        _g--;
        _i = _group.stories.length - 1;
      });
    } else {
      setState(() => _i = 0);
    }
    _show();
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final c = _ctrl;
    final videoReady =
        story.isVideo && c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media
            if (videoReady)
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              )
            else if (!story.isVideo)
              Image.network(
                story.mediaUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accent)),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white38, size: 56),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            // Tap zones: left = previous, right = next
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _prev,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _next,
                  ),
                ),
              ],
            ),
            // Top: progress bars + header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        for (var j = 0; j < _group.stories.length; j++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Container(
                                  height: 3,
                                  color: Colors.white24,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: j < _i
                                        ? 1
                                        : j == _i
                                            ? _progress
                                            : 0,
                                    child:
                                        Container(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.card,
                          backgroundImage: _group.userPhoto.isNotEmpty
                              ? NetworkImage(_group.userPhoto)
                              : null,
                          child: _group.userPhoto.isNotEmpty
                              ? null
                              : Text(
                                  _group.userName.isNotEmpty
                                      ? _group.userName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _group.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _timeAgo(story.createdAt),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Own stories get an Add button inside the viewer.
            if (_isMine)
              Positioned(
                right: 14,
                bottom: 26,
                child: GestureDetector(
                  onTap: () async {
                    await addStoryFlow(context);
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Add story',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
