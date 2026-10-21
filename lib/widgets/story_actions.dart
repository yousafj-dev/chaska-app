import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/services/storage_service.dart';

/// Full add-story flow: choose photo or video → pick from the
/// gallery → upload to Cloudinary → save the story doc.
/// Shows friendly English toasts/dialogs; never throws.
Future<void> addStoryFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_outlined,
                color: AppTheme.accent),
            title: const Text('Photo',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, 'image'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined,
                color: AppTheme.accent),
            title: const Text('Video',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, 'video'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final isVideo = choice == 'video';

  final picker = ImagePicker();
  XFile? picked;
  try {
    picked = isVideo
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 60),
          )
        : await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
            maxWidth: 1280,
          );
  } on PlatformException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.code == 'already_active'
            ? 'The picker is already open, please wait a moment.'
            : 'Could not open the picker. Please try again.'),
      ),
    );
    return;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Could not open the picker. Please try again.')),
    );
    return;
  }
  if (picked == null || !context.mounted) return;

  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      backgroundColor: AppTheme.card,
      content: Row(
        children: [
          CircularProgressIndicator(color: AppTheme.accent),
          SizedBox(width: 16),
          Text('Uploading story...',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
  try {
    final url = await StorageService.instance.uploadStoryMedia(
      File(picked.path),
      isVideo: isVideo,
    );
    await FirestoreService.instance.addStory(
      mediaUrl: url,
      mediaType: choice,
    );
    nav.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your story is live!')),
    );
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }
}
