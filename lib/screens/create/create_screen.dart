import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/screens/create/camera_record_screen.dart';
import 'package:chaska/screens/create/edit_video_screen.dart';

/// Create hub (the + tab): "Record" opens the in-app camera,
/// "Upload" picks from the gallery. Both routes land on the edit
/// screen (filters / music / text) before posting.
///
/// [initialSoundName] pre-attaches a sound (sound page's
/// "Use this sound") and is forwarded to the edit screen.
class CreateScreen extends StatefulWidget {
  final String? initialSoundName;

  const CreateScreen({super.key, this.initialSoundName});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _picker = ImagePicker();
  bool _picking = false;
  String? _error;

  Future<void> _pickFromGallery() async {
    // Re-entrancy guard: image_picker throws
    // PlatformException(already_active) if a pick is already running.
    if (_picking) return;
    _picking = true;
    setState(() => _error = null);
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditVideoScreen(
            videoPath: file.path,
            initialSoundName: widget.initialSoundName,
          ),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('pickVideo PlatformException: ${e.code}');
      if (!mounted) return;
      setState(() => _error = e.code == 'already_active'
          ? 'The picker is already open, please wait a moment.'
          : 'Could not pick a video. Please try again.');
    } catch (e) {
      debugPrint('pickVideo failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Could not pick a video. Please try again.');
    } finally {
      _picking = false;
    }
  }

  void _openRecorder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CameraRecordScreen(initialSoundName: widget.initialSoundName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _entryCard(
              icon: Icons.videocam_outlined,
              title: 'Record',
              subtitle:
                  'Shoot with the in-app camera — filters, music and text after',
              onTap: _openRecorder,
            ),
            const SizedBox(height: 16),
            _entryCard(
              icon: Icons.video_library_outlined,
              title: 'Upload',
              subtitle:
                  'Pick a video from your gallery (up to 60 seconds)',
              onTap: _picking ? null : _pickFromGallery,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.accent2, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _entryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
