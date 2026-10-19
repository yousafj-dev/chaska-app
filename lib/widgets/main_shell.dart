import 'package:flutter/material.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/screens/home/home_screen.dart';
import 'package:chaska/screens/discover/discover_screen.dart';
import 'package:chaska/screens/upload/upload_screen.dart';
import 'package:chaska/screens/inbox/inbox_screen.dart';
import 'package:chaska/screens/profile/profile_screen.dart';

/// Bottom nav shell: Home, Discover, big center Upload button,
/// Inbox, Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    DiscoverScreen(),
    // index 2 is the upload button, not a page
    InboxScreen(),
    ProfileScreen(),
  ];

  void _onTap(int i) {
    if (i == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UploadScreen()),
      );
      return;
    }
    setState(() => _index = i > 2 ? i - 1 : i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Home feed draws edge-to-edge; other tabs get normal padding.
      body: _pages[_index],
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
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
}
