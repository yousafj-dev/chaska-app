import 'package:flutter/material.dart';

/// Static in-app information pages: Help Center, Privacy Policy
/// and Terms and Policies. Short, honest text about what the app
/// actually does with data — no boilerplate promises the app
/// doesn't keep.
class StaticInfoPage extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;

  const StaticInfoPage({
    super.key,
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (heading, body) in sections) ...[
            Text(
              heading,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

StaticInfoPage helpCenterPage() => const StaticInfoPage(
      title: 'Help Center',
      sections: [
        (
          'How do I post a video?',
          'Tap the + button at the bottom, record with the in-app '
              'camera or pick a video from your gallery, add filters, '
              'music or text on the edit screen, then post. Videos '
              'are limited to 60 seconds when recorded in the app.',
        ),
        (
          'Why do I have to log in again?',
          'You should not have to. Chaska keeps you signed in on '
              'this device until you choose Log out or Switch '
              'account in Settings. If you were signed out, check '
              'that the app was not cleared from your phone\'s app '
              'settings.',
        ),
        (
          'How do filters and effects work?',
          'Colour filters preview live on the camera while you '
              'record and are applied to the posted video exactly '
              'as you saw them. A few structural effects cannot be '
              'shown on a live camera feed; the app says so on '
              'screen and applies them when the video is posted.',
        ),
        (
          'How do I stop seeing someone\'s videos?',
          'Open their profile and tap Block in the top-right menu. '
              'Their videos leave your feed immediately. You can '
              'unblock anyone at any time in Settings → Blocked '
              'accounts.',
        ),
        (
          'How do I delete my account?',
          'Settings → Delete account. This permanently removes '
              'your profile, your videos and your activity from the '
              'app and cannot be undone.',
        ),
      ],
    );

StaticInfoPage privacyPolicyPage() => const StaticInfoPage(
      title: 'Privacy Policy',
      sections: [
        (
          'What we store',
          'Your account (email address, display name, profile '
              'photo and bio) is stored in Google Firebase. Videos '
              'and profile photos you upload are stored with '
              'Cloudinary. Your likes, comments, follows, favorites '
              'and watch history are stored in Firebase so the app '
              'can show them back to you.',
        ),
        (
          'What other people can see',
          'Your profile, your videos, your comments and your '
              'follower/following counts are visible to other '
              'signed-in users. Your email address is never shown '
              'to other users.',
        ),
        (
          'What stays on your phone',
          'Videos you save for offline watching stay in the app\'s '
              'own folder on your device and are never uploaded '
              'anywhere. App preferences such as Data Saver are also '
              'stored only on your device.',
        ),
        (
          'Deleting your data',
          'Deleting your account (Settings → Delete account) '
              'removes your profile, videos, comments, likes and '
              'follows from the app\'s database and deletes your '
              'login. Media files already uploaded to the storage '
              'provider cannot be individually erased by the app, '
              'but they are no longer linked to your account or '
              'shown anywhere in the app.',
        ),
        (
          'Changes',
          'If this policy changes, the updated text will appear '
              'here in the app.',
        ),
      ],
    );

StaticInfoPage termsPage() => const StaticInfoPage(
      title: 'Terms and Policies',
      sections: [
        (
          'Your account',
          'You are responsible for your account and for everything '
              'posted from it. Use an email address you control — '
              'password resets are sent there.',
        ),
        (
          'Your videos',
          'You keep ownership of the videos you post. By posting, '
              'you give Chaska permission to store and show them to '
              'other users inside the app. Do not post content you '
              'have no right to use, or content that is illegal, '
              'hateful or harmful.',
        ),
        (
          'Reports and moderation',
          'Any user can report a video or an account. Reported '
              'content is reviewed and may be removed. Accounts '
              'that repeatedly break these terms may be suspended.',
        ),
        (
          'Availability',
          'Chaska is provided as-is, without guarantees of '
              'availability. Features may change or be removed as '
              'the app develops.',
        ),
      ],
    );

/// About page body text (used by the Settings "About" row).
const String aboutText =
    'Chaska — short videos. Watch, create, enjoy.';
