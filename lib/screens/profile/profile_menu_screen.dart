import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/models/chaska_user.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/profile/activity_center_screen.dart';
import 'package:chaska/screens/profile/offline_videos_screen.dart';
import 'package:chaska/screens/profile/qr_code_screen.dart';
import 'package:chaska/screens/profile/settings_screen.dart';

/// Profile menu (from the ☰ button on the profile): the TikTok-
/// style list of account tools — Activity center, Offline videos,
/// Your QR code, Settings and privacy. Rounded cards on the app
/// theme, same row layout as the reference (icon, label, chevron).
class ProfileMenuScreen extends StatelessWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final uid = auth.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (uid != null && AuthService.firebaseReady)
            StreamBuilder<ChaskaUser?>(
              stream: FirestoreService.instance.userProfile(uid),
              builder: (context, snap) =>
                  _items(context, auth, snap.data),
            )
          else
            _items(context, auth, null),
        ],
      ),
    );
  }

  Widget _items(BuildContext context, AuthService auth, ChaskaUser? profile) {
    final name = (profile != null && profile.displayName.isNotEmpty)
        ? profile.displayName
        : auth.displayName;
    final photo = (profile != null && profile.photoUrl.isNotEmpty)
        ? profile.photoUrl
        : (auth.photoUrl ?? '');
    return Column(
      children: [
        _card(
          icon: Icons.access_time_rounded,
          label: 'Activity center',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const ActivityCenterScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _card(
          icon: Icons.cloud_download_outlined,
          label: 'Offline videos',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const OfflineVideosScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _card(
          icon: Icons.qr_code_2_outlined,
          label: 'Your QR code',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QrCodeScreen(
                uid: auth.uid ?? '',
                username: name,
                photoUrl: photo,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _card(
          icon: Icons.settings_outlined,
          label: 'Settings and privacy',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white70, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
