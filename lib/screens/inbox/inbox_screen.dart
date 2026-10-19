import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';

/// Inbox: notifications list. Empty state for the structure build —
/// real notifications arrive with the Firebase-backed phase.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  size: 44,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Koi notification nahi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Jab koi tumhari video like karega ya comment karega, yahan ayega.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
