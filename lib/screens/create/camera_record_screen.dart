import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/screens/create/edit_video_screen.dart';
import 'package:chaska/services/video_edit_service.dart';

/// In-app camera recorder: FULL-SCREEN live preview (cover fit,
/// portrait), front/back flip, elapsed timer, 60-second max with
/// auto-stop, and a TikTok-style live filter row above the record
/// button — tapping a filter tints the preview immediately, and
/// the chosen filter is carried into the edit screen pre-selected
/// so the posted video gets that exact filter baked in. The
/// finished recording goes to the edit screen before posting.
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

  /// Live filter selected on the record screen (Normal by
  /// default). Previewed via [VideoFilter.previewMatrix]; carried
  /// into the edit screen so it is baked when the video posts.
  VideoFilter _filter = VideoFilters.all.first;

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
            initialFilterName: _filter.name,
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
                  _fullScreenPreview(c),
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
                  bottom: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _filtersRow(),
                      const SizedBox(height: 14),
                      Row(
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
                                border: Border.all(
                                    color: Colors.white, width: 4),
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
                            icon: const Icon(
                                Icons.flip_camera_ios_outlined,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// The camera preview scaled to COVER the whole screen (the
  /// standard cover recipe for the camera plugin): without this
  /// the preview renders as a small landscape strip in the middle
  /// of the portrait screen. The live filter's preview matrix is
  /// applied over it when one is selected.
  Widget _fullScreenPreview(CameraController c) {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * c.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    Widget preview = Transform.scale(
      scale: scale,
      child: Center(child: CameraPreview(c)),
    );
    final matrix = _filter.previewMatrix;
    if (matrix != null) {
      preview = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: preview,
      );
    }
    return ClipRect(child: preview);
  }

  /// TikTok/Snapchat-style filter strip above the record button:
  /// the same 20 colour filters as the edit screen. Each chip is a
  /// small circular swatch (tinted by the filter's own matrix) with
  /// the filter name under it; the selected chip gets a violet ring.
  Widget _filtersRow() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: VideoFilters.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = VideoFilters.all[i];
          final selected = f.name == _filter.name;
          Widget swatch = Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF9E7BD8),
                  Color(0xFF3E2A5A),
                  Color(0xFFE8B04B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          );
          if (f.previewMatrix != null) {
            swatch = ColorFiltered(
              colorFilter: ColorFilter.matrix(f.previewMatrix!),
              child: swatch,
            );
          }
          return GestureDetector(
            onTap: _recording
                ? null
                : () => setState(() => _filter = f),
            child: SizedBox(
              width: 54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppTheme.accent
                            : Colors.white38,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: ClipOval(child: swatch),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
