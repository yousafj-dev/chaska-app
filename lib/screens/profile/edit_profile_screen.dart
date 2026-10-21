import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/services/storage_service.dart';

/// Edit profile: photo (Cloudinary), nickname and bio.
/// Saves to Firestore `users/{uid}` and the FirebaseAuth profile.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _picker = ImagePicker();
  String _photoUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = AuthService.instance;
    _name.text = auth.displayName;
    _photoUrl = auth.photoUrl ?? '';
    final uid = auth.uid;
    if (uid != null && AuthService.firebaseReady) {
      final profile = await FirestoreService.instance.getUserProfile(uid);
      if (profile != null) {
        if (profile.displayName.isNotEmpty) _name.text = profile.displayName;
        if (profile.photoUrl.isNotEmpty) _photoUrl = profile.photoUrl;
        _bio.text = profile.bio;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _friendlyErr(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.startsWith('PlatformException')) {
      return 'Could not select a photo. Please try again.';
    }
    return msg;
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto || _saving) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (picked == null) return;
      setState(() {
        _uploadingPhoto = true;
        _error = null;
      });
      final url = await StorageService.instance
          .uploadProfileImage(File(picked.path));
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyErr(e));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) {
      setState(() => _error = 'Please log in first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirestoreService.instance.updateUserProfile(
        uid: uid,
        displayName: name,
        photoUrl: _photoUrl,
        bio: _bio.text.trim(),
      );
      await auth.updateProfile(displayName: name, photoUrl: _photoUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = _friendlyErr(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _changePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor:
                                AppTheme.accent.withOpacity(0.2),
                            backgroundImage: _photoUrl.isNotEmpty
                                ? NetworkImage(_photoUrl)
                                : null,
                            child: _photoUrl.isEmpty
                                ? Text(
                                    _name.text.isNotEmpty
                                        ? _name.text[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accent,
                                    ),
                                  )
                                : null,
                          ),
                          if (_uploadingPhoto)
                            const Positioned.fill(
                              child: CircularProgressIndicator(
                                color: AppTheme.accent2,
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                                border:
                                    Border.all(color: AppTheme.bg, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the photo to change it',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Nickname',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'Enter your name / nickname',
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Bio',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bio,
                    maxLines: 3,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      hintText: 'Write something about yourself...',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: AppTheme.accent2, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _saving || _uploadingPhoto ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
