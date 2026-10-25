import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/services/prefs_service.dart';
import 'package:chaska/screens/auth/auth_screen.dart';
import 'package:chaska/screens/profile/blocked_accounts_screen.dart';
import 'package:chaska/screens/profile/edit_profile_screen.dart';
import 'package:chaska/screens/profile/static_pages.dart';

/// Settings and privacy — REAL items only, grouped like the big
/// apps: Account (information, edit profile, change password),
/// Privacy (blocked accounts), Notifications (per-type toggles
/// the Inbox actually honours), Playback (Data Saver), Storage
/// (free up space), Support (help / privacy / terms / about) and
/// the session actions (switch account, log out, delete account).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// Must match `version` in pubspec.yaml.
  static const String appVersion = '1.0.0';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dataSaver = PrefsService.dataSaver;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings and privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Account'),
          const SizedBox(height: 8),
          _card([
            _row(
              icon: Icons.mail_outline,
              label: 'Email',
              value: auth.email ?? '—',
            ),
            _divider(),
            _row(
              icon: Icons.alternate_email,
              label: 'Display name',
              value: '@${auth.displayName}',
            ),
            _divider(),
            _row(
              icon: Icons.badge_outlined,
              label: 'User ID',
              value: uid ?? '—',
            ),
          ]),
          const SizedBox(height: 10),
          _navRow(
            icon: Icons.edit_outlined,
            label: 'Edit profile',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _navRow(
            icon: Icons.lock_outline,
            label: 'Change password',
            onTap: _busy ? null : _changePassword,
          ),
          const SizedBox(height: 22),
          _sectionLabel('Privacy'),
          const SizedBox(height: 8),
          _navRow(
            icon: Icons.block_outlined,
            label: 'Blocked accounts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const BlockedAccountsScreen()),
            ),
          ),
          const SizedBox(height: 22),
          _sectionLabel('Notifications'),
          const SizedBox(height: 8),
          if (uid != null && AuthService.firebaseReady)
            StreamBuilder<ChaskaUser?>(
              stream: FirestoreService.instance.userProfile(uid),
              builder: (context, snap) {
                final p = snap.data;
                return _card([
                  _switchRow(
                    icon: Icons.favorite_border,
                    label: 'Likes',
                    value: p?.notifLikes ?? true,
                    onChanged: (v) => FirestoreService.instance
                        .setNotifPrefs(likes: v),
                  ),
                  _divider(),
                  _switchRow(
                    icon: Icons.comment_outlined,
                    label: 'Comments',
                    value: p?.notifComments ?? true,
                    onChanged: (v) => FirestoreService.instance
                        .setNotifPrefs(comments: v),
                  ),
                  _divider(),
                  _switchRow(
                    icon: Icons.person_add_outlined,
                    label: 'New followers',
                    value: p?.notifFollows ?? true,
                    onChanged: (v) => FirestoreService.instance
                        .setNotifPrefs(follows: v),
                  ),
                ]);
              },
            )
          else
            _hint('Log in to manage notification settings.'),
          const SizedBox(height: 22),
          _sectionLabel('Playback'),
          const SizedBox(height: 8),
          _card([
            _switchRow(
              icon: Icons.data_saver_on_outlined,
              label: 'Data Saver',
              subtitle: 'Lighter video quality in the feed',
              value: _dataSaver,
              onChanged: (v) async {
                setState(() => _dataSaver = v);
                await PrefsService.setDataSaver(v);
              },
            ),
          ]),
          const SizedBox(height: 22),
          _sectionLabel('Storage'),
          const SizedBox(height: 8),
          _navRow(
            icon: Icons.cleaning_services_outlined,
            label: 'Free up space',
            onTap: _freeUpSpace,
          ),
          const SizedBox(height: 22),
          _sectionLabel('Support'),
          const SizedBox(height: 8),
          _navRow(
            icon: Icons.help_outline,
            label: 'Help Center',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => helpCenterPage()),
            ),
          ),
          const SizedBox(height: 10),
          _navRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => privacyPolicyPage()),
            ),
          ),
          const SizedBox(height: 10),
          _navRow(
            icon: Icons.description_outlined,
            label: 'Terms and Policies',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => termsPage()),
            ),
          ),
          const SizedBox(height: 10),
          _card([
            _row(
              icon: Icons.info_outline,
              label: 'About Chaska',
              value: 'Version ${SettingsScreen.appVersion}',
            ),
          ]),
          const SizedBox(height: 22),
          _sectionLabel('Login'),
          const SizedBox(height: 8),
          _navRow(
            icon: Icons.switch_account_outlined,
            label: 'Switch account',
            onTap: _busy ? null : () => _signOut(confirm: false),
          ),
          const SizedBox(height: 10),
          _navRow(
            icon: Icons.logout_outlined,
            label: 'Log out',
            onTap: _busy ? null : () => _signOut(confirm: true),
          ),
          const SizedBox(height: 10),
          _navRow(
            icon: Icons.delete_forever_outlined,
            label: 'Delete account',
            danger: true,
            onTap: _busy ? null : _deleteAccount,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Change password',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pwField(current, 'Current password'),
            const SizedBox(height: 10),
            _pwField(next, 'New password'),
            const SizedBox(height: 10),
            _pwField(confirm, 'Confirm new password'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (next.text != confirm.text) {
      _msg('New passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context
          .read<AuthService>()
          .changePassword(current.text, next.text);
      if (mounted) _msg('Password changed.');
    } catch (e) {
      if (mounted) _msg(_clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut({required bool confirm}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dlg) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Log out?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'You will need to log in again to use Chaska.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlg, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dlg, true),
              child: const Text('Log out'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  /// Delete account: warn → confirm with password → re-authenticate
  /// FIRST (a wrong password must abort before anything is
  /// deleted) → delete Firestore data → delete the Auth user.
  Future<void> _deleteAccount() async {
    final warn = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Delete account?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This permanently deletes your profile, your videos, '
          'your comments, likes and follows, and your login. '
          'It cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('Continue',
                style: TextStyle(color: AppTheme.accent2)),
          ),
        ],
      ),
    );
    if (warn != true || !mounted) return;

    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Confirm with your password',
            style: TextStyle(color: Colors.white)),
        content: _pwField(password, 'Current password'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('Delete forever',
                style: TextStyle(color: AppTheme.accent2)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    try {
      await auth.reauthenticate(password.text);
      await FirestoreService.instance.deleteMyAccountData();
      await auth.deleteAccount(password.text);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _msg(_clean(e));
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  /// Shows temp/cache size next to the offline-downloads size and
  /// offers to clear the cache. Offline downloads are NOT touched
  /// here — they are managed in Profile → Offline videos.
  Future<void> _freeUpSpace() async {
    int cacheBytes = 0;
    int offlineBytes = 0;
    Directory? temp;
    try {
      temp = await getTemporaryDirectory();
      cacheBytes = await _dirSize(temp);
      final docs = await getApplicationDocumentsDirectory();
      offlineBytes =
          await _dirSize(Directory('${docs.path}/offline_videos'));
    } catch (e) {
      debugPrint('freeUpSpace measure failed: $e');
    }
    if (!mounted) return;
    final clear = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Free up space',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'App cache: ${_formatBytes(cacheBytes)}\n'
          'Offline videos: ${_formatBytes(offlineBytes)} '
          '(kept — manage them in Profile → Offline videos)',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('Clear cache'),
          ),
        ],
      ),
    );
    if (clear != true || temp == null) return;
    try {
      await for (final entity in temp.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) _msg('Cache cleared.');
    } catch (e) {
      if (mounted) _msg('Could not clear the cache.');
    }
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---------------------------------------------------------------
  // Small building blocks
  // ---------------------------------------------------------------

  Widget _pwField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.muted),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(
      color: Colors.white10, height: 1, indent: 56);

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 21),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? AppTheme.accent2 : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: danger ? AppTheme.accent2 : Colors.white70,
                size: 21),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppTheme.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) {
    return Text(
      text,
      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
    );
  }
}
