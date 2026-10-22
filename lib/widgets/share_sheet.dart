import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/services/offline_service.dart';

/// TikTok-style "Share to" bottom sheet for one feed video.
///
/// Real actions only: Repost (toggle), Favorite (toggle), Download
/// video (saved for offline watching), Copy link, system Share
/// (surfaces WhatsApp / Facebook / …), Not interested (hides the
/// video from this user's feed) and Report (moderation queue).
void showShareSheet(BuildContext context, ChaskaVideo video) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ShareSheet(video: video),
  );
}

class _ShareSheet extends StatelessWidget {
  final ChaskaVideo video;

  const _ShareSheet({required this.video});

  bool _loggedIn(BuildContext context) {
    final auth = AuthService.instance;
    if (AuthService.firebaseReady && auth.isSignedIn) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first.')),
    );
    return false;
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _shareText() {
    final caption = video.caption.trim();
    return caption.isNotEmpty
        ? '$caption\n${video.videoUrl}'
        : 'Watch this video on Chaska!\n${video.videoUrl}';
  }

  Future<void> _toggleRepost(BuildContext context) async {
    if (!_loggedIn(context)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = await FirestoreService.instance.toggleRepost(video);
      messenger.showSnackBar(SnackBar(
          content: Text(
              now ? 'Reposted to your profile' : 'Repost removed')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    if (!_loggedIn(context)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = await FirestoreService.instance.toggleFavorite(video);
      messenger.showSnackBar(SnackBar(
          content: Text(
              now ? 'Saved to favorites' : 'Removed from favorites')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (await OfflineService.instance.isDownloaded(video.id)) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Already saved for offline')));
      return;
    }
    final progress = ValueNotifier<double>(0);
    // Progress dialog above the sheet; popped when the download ends.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Downloading video',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, p, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: p > 0 ? p : null,
                backgroundColor: Colors.white12,
                color: AppTheme.accent,
                minHeight: 8,
              ),
              const SizedBox(height: 10),
              Text('${(p * 100).toInt()}%',
                  style: const TextStyle(color: AppTheme.muted)),
            ],
          ),
        ),
      ),
    );
    try {
      await OfflineService.instance.download(
        video,
        onProgress: (p) => progress.value = p,
      );
      nav.pop(); // progress dialog
      nav.pop(); // share sheet
      messenger.showSnackBar(
          const SnackBar(content: Text('Saved for offline')));
    } catch (e) {
      nav.pop(); // progress dialog
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: video.videoUrl));
    await FirestoreService.instance.incrementShare(video.id);
    if (context.mounted) _toast(context, 'Link copied');
  }

  Future<void> _systemShare(BuildContext context) async {
    await Share.share(_shareText());
    await FirestoreService.instance.incrementShare(video.id);
  }

  Future<void> _notInterested(BuildContext context) async {
    if (!_loggedIn(context)) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await FirestoreService.instance.hideVideo(video.id);
      nav.pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Video hidden from your feed')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _report(BuildContext context) async {
    if (!_loggedIn(context)) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await FirestoreService.instance.reportVideo(video.id);
      nav.pop();
      messenger.showSnackBar(const SnackBar(
          content: Text("Thanks, we'll review this video")));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: "Share to" + close
            Row(
              children: [
                const SizedBox(width: 40),
                const Expanded(
                  child: Text(
                    'Share to',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 18,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                // Repost — live toggle state
                StreamBuilder<bool>(
                  stream: FirestoreService.instance.isReposted(video.id),
                  builder: (context, snap) {
                    final active = snap.data ?? false;
                    return _tile(
                      icon: Icons.repeat,
                      color: active
                          ? AppTheme.accent2
                          : const Color(0xFFF5C518),
                      label: 'Repost',
                      onTap: () => _toggleRepost(context),
                    );
                  },
                ),
                // Favorite — live toggle state
                StreamBuilder<bool>(
                  stream: FirestoreService.instance.isFavorite(video.id),
                  builder: (context, snap) {
                    final active = snap.data ?? false;
                    return _tile(
                      icon: active ? Icons.bookmark : Icons.bookmark_border,
                      color: active ? AppTheme.accent2 : Colors.white,
                      label: 'Favorite',
                      onTap: () => _toggleFavorite(context),
                    );
                  },
                ),
                _tile(
                  icon: Icons.download_outlined,
                  color: Colors.white,
                  label: 'Download',
                  onTap: () => _download(context),
                ),
                _tile(
                  icon: Icons.link,
                  color: Colors.white,
                  label: 'Copy link',
                  onTap: () => _copyLink(context),
                ),
                _tile(
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: 'Share',
                  onTap: () => _systemShare(context),
                ),
                _tile(
                  icon: Icons.visibility_off_outlined,
                  color: Colors.white70,
                  label: 'Not interested',
                  onTap: () => _notInterested(context),
                ),
                _tile(
                  icon: Icons.flag_outlined,
                  color: Colors.white70,
                  label: 'Report',
                  onTap: () => _report(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One circular action tile: filled disc, icon, label underneath.
  Widget _tile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
