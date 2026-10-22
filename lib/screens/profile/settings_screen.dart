import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/screens/auth/auth_screen.dart';

/// Settings and privacy: the signed-in account's email + username,
/// the app version, and Log out. (Real items only — no fake
/// toggles.) Logging out ends the Firebase session, so the next
/// app open correctly lands on the login screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Must match `version` in pubspec.yaml.
  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings and privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Account'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _row(
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: '@${auth.displayName}',
                ),
                const Divider(
                    color: Colors.white10, height: 1, indent: 56),
                _row(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: auth.email ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionLabel('About'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _row(
              icon: Icons.info_outline,
              label: 'Version',
              value: appVersion,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_outlined, size: 18),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent2,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: AppTheme.accent2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

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
}
