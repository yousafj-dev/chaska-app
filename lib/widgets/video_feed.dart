import 'package:flutter/material.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/widgets/video_card.dart';

/// Vertical TikTok-style pager over a fixed list of videos.
/// Only the visible page's player plays; each page is keyed by
/// its video's document id so a card can never be re-bound to a
/// different video while keeping a stale player. The next page's
/// player is pre-initialized (paused) so swiping starts playback
/// instantly; pages that scroll out of the viewport are disposed
/// by the PageView itself, which tears their players down.
class PagedVideoFeed extends StatefulWidget {
  final List<ChaskaVideo> videos;
  final int initialPage;

  const PagedVideoFeed({
    super.key,
    required this.videos,
    this.initialPage = 0,
  });

  @override
  State<PagedVideoFeed> createState() => _PagedVideoFeedState();
}

class _PagedVideoFeedState extends State<PagedVideoFeed> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPage
        .clamp(0, widget.videos.isEmpty ? 0 : widget.videos.length - 1);
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.videos;
    if (_current >= videos.length) _current = 0;
    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      itemCount: videos.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (context, i) => VideoCard(
        key: ValueKey(videos[i].id),
        video: videos[i],
        isActive: i == _current,
        preload: i == _current + 1,
      ),
    );
  }
}
