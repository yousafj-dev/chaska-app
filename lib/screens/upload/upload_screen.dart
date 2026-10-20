import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/services/storage_service.dart';

/// Upload: pick a video, preview it, add a caption, upload to
/// Firebase Storage + save the Firestore doc. Requires login.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _caption = TextEditingController();
  final _picker = ImagePicker();
  XFile? _picked;
  VideoPlayerController? _preview;
  bool _uploading = false;
  bool _picking = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    // Re-entrancy guard: a second tap while the picker is already open
    // makes image_picker throw PlatformException(already_active).
    if (_picking) return;
    _picking = true;
    setState(() => _error = null);
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null) return;
      await _preview?.dispose();
      final c = VideoPlayerController.file(File(file.path));
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _picked = file;
        _preview = c;
      });
      c.play();
    } on PlatformException catch (e) {
      debugPrint('pickVideo PlatformException: ${e.code}');
      if (!mounted) return;
      setState(() => _error = e.code == 'already_active'
          ? 'Picker pehle se khula hai, ek lamha ruko.'
          : 'Video choose nahi ho saki, dobara try karo.');
    } catch (e) {
      debugPrint('pickVideo failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Video choose nahi ho saki, dobara try karo.');
    } finally {
      _picking = false;
    }
  }

  Future<void> _upload() async {
    if (_picked == null) {
      setState(() => _error = 'Pehle video choose karo.');
      return;
    }
    final auth = AuthService.instance;
    if (!AuthService.firebaseReady || !auth.isSignedIn) {
      setState(() =>
          _error = 'Upload ke liye pehle login karo.');
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final url = await StorageService.instance.uploadVideo(
        File(_picked!.path),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await FirestoreService.instance.addVideo(
        videoUrl: url,
        caption: _caption.text.trim(),
        uid: auth.uid!,
        username: auth.displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video upload ho gayi!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nayi video')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!AuthService.firebaseReady)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Offline mode: Firebase setup ke baad upload chalega.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            GestureDetector(
              onTap: _uploading
                  ? null
                  : () => _showPickSheet(),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: _preview != null
                    ? AspectRatio(
                        aspectRatio: _preview!.value.aspectRatio,
                        child: VideoPlayer(_preview!),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_call_outlined,
                              size: 56, color: AppTheme.accent),
                          SizedBox(height: 10),
                          Text('Video choose karo',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Gallery ya camera (60 sec tak)',
                              style: TextStyle(
                                  color: AppTheme.muted, fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _caption,
              maxLines: 3,
              maxLength: 150,
              decoration: const InputDecoration(
                hintText: 'Caption likho... #chaska',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppTheme.accent, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            if (_uploading) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppTheme.card,
                color: AppTheme.accent,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload ho rahi hai... ${(_progress * 100).toInt()}%',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload karo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickSheet() {
    showModalBottomSheet(
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
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.accent),
              title: const Text('Gallery se choose karo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined,
                  color: AppTheme.accent),
              title: const Text('Camera se banao',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
