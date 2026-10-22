import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:chaska/core/theme/app_theme.dart';

/// "Your QR code": a scannable code encoding this user's Chaska
/// profile link (`chaska://user/{uid}`), shown TikTok-style with
/// the avatar and @username under it.
class QrCodeScreen extends StatelessWidget {
  final String uid;
  final String username;
  final String photoUrl;

  const QrCodeScreen({
    super.key,
    required this.uid,
    required this.username,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your QR code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: 'chaska://user/$uid',
                  version: QrVersions.auto,
                  size: 230,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0D0A14),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0D0A14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.accent.withOpacity(0.2),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isNotEmpty
                    ? null
                    : Text(
                        username.isNotEmpty
                            ? username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                '@$username',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Friends can scan this code to open your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
