import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/screens/create/edit_video_screen.dart';

/// In-app camera recorder: live preview, front/back flip, elapsed
/// timer, 60-second max with auto-stop. The finished recording goes to
/// the edit screen (filters / music / text) before posting.
class CameraRecordScreen extends StatefulWidget {
  /// Sound name pre-attached from a sound page's "Use this sound".
  final String? initialSoundName;

  const CameraRecordScreen({super.key, this.initialSoundName});

  @override
  State<CameraRecordScreen> createState() => _CameraRecordScreenState();
}

class _CameraRecordScreenState extends State<CameraRecordScreen>
    with WidgetsBindingObserver {
  static const _maxSeconds = 60;

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _recording = false;
  int _elapsed = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameraIndex);
    }
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'No camera was found on this device.';
          });
        }
        return;
      }
      // Start with the back camera when there is one.
      final back = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back);
      _cameraIndex = back >= 0 ? back : 0;
      await _initCamera(_cameraIndex);
    } catch (e) {
      debugPrint('camera setup failed: $e');
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Camera is not available. Please check permissions.';
        });
      }
    }
  }

  Future<void> _initCamera(int index) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    final c = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _initializing = false;
      });
    } on CameraException catch (e) {
      debugPrint('camera init failed: ${e.code}');
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.code == 'CameraAccessDenied'
              ? 'Camera permission was denied. Please allow it in Settings.'
              : 'Camera could not start. Please try again.';
        });
      }
    }
  }

  Future<void> _flip() async {
    if (_recording || _cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    await _initCamera(_cameraIndex);
  }

  Future<void> _toggleRecord() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_recording) {
      await _stop();
      return;
    }
    try {
      await c.startVideoRecording();
      _timer?.cancel();
      _elapsed = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_elapsed >= _maxSeconds) _stop();
      });
      setState(() => _recording = true);
    } on CameraException catch (e) {
      debugPrint('start recording failed: ${e.code}');
      _showError('Recording could not start. Please try again.');
    }
  }

  Future<void> _stop() async {
    final c = _controller;
    if (c == null || !_recording) return;
    _timer?.cancel();
    setState(() => _recording = false);
    try {
      final file = await c.stopVideoRecording();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditVideoScreen(
            videoPath: file.path,
            initialSoundName: widget.initialSoundName,
          ),
        ),
      );
    } on CameraException catch (e) {
      debugPrint('stop recording failed: ${e.code}');
      _showError('The recording could not be saved. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _timeLabel {
    final m = (_elapsed ~/ 60).toString();
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s / 1:00';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Record'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_initializing || c == null)
                  const Center(child: CircularProgressIndicator())
                else
                  Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: CameraPreview(c),
                    ),
                  ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 64,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_recording)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.circle,
                                  color: Colors.redAccent, size: 10),
                            ),
                          Text(_timeLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 56),
                      GestureDetector(
                        onTap: _toggleRecord,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: Container(
                              width: _recording ? 30 : 58,
                              height: _recording ? 30 : 58,
                              decoration: BoxDecoration(
                                color: AppTheme.accent2,
                                shape: _recording
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                                borderRadius: _recording
                                    ? BorderRadius.circular(6)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _flip,
                        iconSize: 34,
                        icon: const Icon(Icons.flip_camera_ios_outlined,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
