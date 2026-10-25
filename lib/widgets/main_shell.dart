import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/screens/home/home_screen.dart';
import 'package:chaska/screens/discover/discover_screen.dart';
import 'package:chaska/screens/create/create_screen.dart';
import 'package:chaska/screens/inbox/inbox_screen.dart';
import 'package:chaska/screens/profile/profile_screen.dart';

/// Bottom nav shell: Home, Discover, big center Upload button,
/// Inbox, Profile.
///
/// Tabs stay MOUNTED (IndexedStack) so the Home feed keeps its
/// scroll position and player when the user hops to another tab
/// and back; the Home screen is told whether it is visible so its
/// video pauses while hidden and resumes from the same position.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Page index: 0 Home, 1 Discover, 2 Inbox, 3 Profile.
  /// (Bottom-bar slot 2 is the Upload button, not a page.)
  int _index = 0;

  void _onTap(int i) {
    if (i == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateScreen()),
      );
      return;
    }
    setState(() => _index = i > 2 ? i - 1 : i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Home feed draws edge-to-edge; other tabs get normal padding.
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(isVisible: _index == 0),
          const DiscoverScreen(),
          InboxScreen(isVisible: _index == 2),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index >= 2 ? _index + 1 : _index,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 52,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accent2, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add,
                  color: Colors.white, size: 26),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _inboxIcon(false),
            activeIcon: _inboxIcon(true),
            label: 'Inbox',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Inbox icon with a live unread-notifications badge.
  Widget _inboxIcon(bool active) {
    final icon =
        Icon(active ? Icons.inbox : Icons.inbox_outlined);
    return StreamBuilder<int>(
      stream: FirestoreService.instance.unreadNotificationCount(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return icon;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accent2,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
