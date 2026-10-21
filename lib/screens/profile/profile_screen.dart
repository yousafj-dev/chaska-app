import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/auth/auth_screen.dart';
import 'package:chaska/screens/profile/edit_profile_screen.dart';
import 'package:chaska/widgets/video_feed.dart';

/// Profile: avatar, nickname, bio (from `users/{uid}`), stats
/// (videos + following counts), my videos grid with thumbnails,
/// edit-profile entry, logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.uid;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: Text('@${auth.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          if (uid != null && AuthService.firebaseReady)
            StreamBuilder<ChaskaUser?>(
              stream: FirestoreService.instance.userProfile(uid),
              builder: (context, snap) => _header(context, auth, snap.data),
            )
          else
            _header(context, auth, null),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const TabBar(
            indicatorColor: AppTheme.accent2,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.muted,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(icon: Icon(Icons.grid_view, size: 20), text: 'Videos'),
              Tab(icon: Icon(Icons.bookmark, size: 20), text: 'Favorites'),
              Tab(icon: Icon(Icons.repeat, size: 20), text: 'Reposts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _videosTab(context, auth),
                _favoritesTab(context, auth),
                _repostsTab(context, auth),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _header(BuildContext context, AuthService auth, ChaskaUser? profile) {
    final name = (profile != null && profile.displayName.isNotEmpty)
        ? profile.displayName
        : auth.displayName;
    final photo = (profile != null && profile.photoUrl.isNotEmpty)
        ? profile.photoUrl
        : (auth.photoUrl ?? '');
    final bio = profile?.bio ?? '';
    final uid = auth.uid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppTheme.accent.withOpacity(0.2),
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isNotEmpty
              ? null
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Text(
          '@$name',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (uid != null && AuthService.firebaseReady)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<List<ChaskaVideo>>(
                stream: FirestoreService.instance.myVideos(uid),
                builder: (context, snap) =>
                    _stat('${snap.data?.length ?? 0}', 'Videos'),
              ),
              const SizedBox(width: 36),
              StreamBuilder<int>(
                stream: FirestoreService.instance.followingCount(uid),
                builder: (context, snap) =>
                    _stat('${snap.data ?? 0}', 'Following'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit profile'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _notLoggedIn() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Log in to see your videos here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted),
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted),
        ),
      ),
    );
  }

  /// Shared stream → grid plumbing for the three profile tabs.
  Widget _tabGrid(
    BuildContext context, {
    required Stream<List<ChaskaVideo>> stream,
    required String emptyText,
    bool canDelete = false,
  }) {
    return StreamBuilder<List<ChaskaVideo>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _emptyState(
              'Could not load videos. Please try again later.');
        }
        final videos = snap.data ?? [];
        if (videos.isEmpty) return _emptyState(emptyText);
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
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
              onLongPress: canDelete
                  ? () => _showVideoOptions(context, v)
                  : null,
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

  /// Long-press menu on one of my own videos.
  void _showVideoOptions(BuildContext context, ChaskaVideo video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppTheme.accent2),
              title: const Text('Delete video',
                  style: TextStyle(color: AppTheme.accent2)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, video);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.close, color: Colors.white70),
              title: const Text('Cancel',
                  style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.pop(sheetCtx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ChaskaVideo video) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Delete video?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Delete this video permanently? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.accent2)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirestoreService.instance.deleteVideo(video);
      messenger.showSnackBar(
        const SnackBar(content: Text('Video deleted')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content:
                Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _videosTab(BuildContext context, AuthService auth) {
    final uid = auth.uid;
    if (!AuthService.firebaseReady || uid == null) return _notLoggedIn();
    return _tabGrid(
      context,
      stream: FirestoreService.instance.myVideos(uid),
      emptyText:
          'You have not uploaded any videos yet.\nTap + below and post your first video!',
      canDelete: true,
    );
  }

  Widget _favoritesTab(BuildContext context, AuthService auth) {
    final uid = auth.uid;
    if (!AuthService.firebaseReady || uid == null) return _notLoggedIn();
    return _tabGrid(
      context,
      stream: FirestoreService.instance.favoriteVideos(uid),
      emptyText:
          'No favorites yet.\nTap the bookmark on any video to save it here.',
    );
  }

  Widget _repostsTab(BuildContext context, AuthService auth) {
    final uid = auth.uid;
    if (!AuthService.firebaseReady || uid == null) return _notLoggedIn();
    return _tabGrid(
      context,
      stream: FirestoreService.instance.repostedVideos(uid),
      emptyText:
          'No reposts yet.\nTap the repost button on a video to share it here.',
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
