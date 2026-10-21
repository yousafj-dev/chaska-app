import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_story.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/home/story_viewer.dart';
import 'package:chaska/widgets/story_actions.dart';

/// Horizontal stories row shown at the top of the home feed.
/// First circle is always "Your story"; live (last 24h) stories of
/// other users follow, grouped one circle per user.
class StoriesRow extends StatefulWidget {
  const StoriesRow({super.key});

  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  @override
  void initState() {
    super.initState();
    StoryViews.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.uid;
    if (!AuthService.firebaseReady || myUid == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 106,
      child: StreamBuilder<List<ChaskaStory>>(
        stream: FirestoreService.instance.storiesFeed(),
        builder: (context, snap) {
          final all = snap.data ?? const <ChaskaStory>[];
          final groups = _groupLive(all);
          final ownList = groups.where((g) => g.uid == myUid).toList();
          final own = ownList.isEmpty ? null : ownList.first;
          final others = groups.where((g) => g.uid != myUid).toList();
          final ordered = [if (own != null) own, ...others];
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _myCircle(myUid, own, ordered),
              for (final g in others)
                _userCircle(g, ordered.indexOf(g), ordered),
            ],
          );
        },
      ),
    );
  }

  /// Groups live stories by user. Query order is newest-first, so
  /// groups appear by most recent activity; stories inside a group
  /// are flipped to oldest-first for playback.
  List<StoryGroup> _groupLive(List<ChaskaStory> all) {
    final byUid = <String, List<ChaskaStory>>{};
    final order = <String>[];
    for (final s in all) {
      if (!s.isLive) continue;
      if (!byUid.containsKey(s.uid)) {
        byUid[s.uid] = [];
        order.add(s.uid);
      }
      byUid[s.uid]!.add(s);
    }
    return [
      for (final uid in order)
        StoryGroup(
          uid: uid,
          userName: byUid[uid]!.first.userName,
          userPhoto: byUid[uid]!.first.userPhoto,
          stories: byUid[uid]!.reversed.toList(),
        ),
    ];
  }

  Widget _myCircle(String myUid, StoryGroup? own, List<StoryGroup> ordered) {
    return StreamBuilder<ChaskaUser?>(
      stream: FirestoreService.instance.userProfile(myUid),
      builder: (context, snap) {
        final photo = (snap.data?.photoUrl.isNotEmpty ?? false)
            ? snap.data!.photoUrl
            : (AuthService.instance.photoUrl ?? '');
        final name = (snap.data?.displayName.isNotEmpty ?? false)
            ? snap.data!.displayName
            : AuthService.instance.displayName;
        return _circle(
          photo: photo,
          name: name,
          label: 'Your story',
          gradient: false,
          badge: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              border: Border.all(color: AppTheme.bg, width: 2),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.white),
          ),
          onTap: () async {
            if (own != null) {
              await _openViewer(ordered, ordered.indexOf(own));
            } else {
              await addStoryFlow(context);
            }
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  Widget _userCircle(StoryGroup g, int index, List<StoryGroup> ordered) {
    final unviewed = !StoryViews.groupViewed(g);
    return _circle(
      photo: g.userPhoto,
      name: g.userName,
      label: g.userName,
      gradient: unviewed,
      onTap: () async {
        await _openViewer(ordered, index);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _openViewer(List<StoryGroup> groups, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewer(groups: groups, initialGroup: index),
      ),
    );
  }

  Widget _circle({
    required String photo,
    required String name,
    required String label,
    required bool gradient,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        gradient ? AppTheme.primaryGradient : null,
                    border: gradient
                        ? null
                        : Border.all(color: Colors.white24, width: 2),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.bg,
                    ),
                    child: CircleAvatar(
                      radius: 28,
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
                                fontSize: 20,
                              ),
                            ),
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(right: 0, bottom: 0, child: badge),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
