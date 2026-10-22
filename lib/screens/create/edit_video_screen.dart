import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chaska/core/theme/app_theme.dart';
import 'package:chaska/services/auth_service.dart';
import 'package:chaska/services/firestore_service.dart';
import 'package:chaska/services/storage_service.dart';
import 'package:chaska/services/video_edit_service.dart';

/// Edit + post screen. Every video (recorded in-app or picked from
/// the gallery) lands here before posting.
///
/// Filters, picked music and text overlay are baked into the posted
/// video with FFmpeg (see [VideoEditService]) — the preview applies a
/// ColorFilter approximation so what you see is close to the result.
/// With no edits chosen the original file is uploaded untouched.
class EditVideoScreen extends StatefulWidget {
  final String videoPath;

  /// Sound name pre-attached from a sound page's "Use this sound".
  final String? initialSoundName;

  /// Filter chosen LIVE on the record screen — pre-selected here
  /// so the posted video gets exactly that filter baked in.
  final String? initialFilterName;

  const EditVideoScreen({
    super.key,
    required this.videoPath,
    this.initialSoundName,
    this.initialFilterName,
  });

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  final _caption = TextEditingController();
  late final TextEditingController _sound;
  final _overlay = TextEditingController();

  VideoPlayerController? _player;
  VideoFilter _filter = VideoFilters.all.first;
  VideoEffect _effect = VideoEffects.all.first;
  MusicMode _musicMode = MusicMode.original;
  String? _musicPath;
  String? _musicName;
  OverlayPosition _textPos = OverlayPosition.bottom;

  bool _posting = false;
  bool _processing = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sound = TextEditingController(text: widget.initialSoundName ?? '');
    final filterName = widget.initialFilterName;
    if (filterName != null) {
      _filter = VideoFilters.all.firstWhere(
        (f) => f.name == filterName,
        orElse: () => VideoFilters.all.first,
      );
    }
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final c = VideoPlayerController.file(File(widget.videoPath));
    await c.initialize();
    await c.setLooping(true);
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _player = c);
    c.play();
  }

  @override
  void dispose() {
    _caption.dispose();
    _sound.dispose();
    _overlay.dispose();
    _player?.dispose();
    super.dispose();
  }

  bool get _hasEdits => VideoEditOptions(
        filter: _filter,
        effect: _effect,
        musicMode: _musicMode,
        musicPath: _musicPath,
        overlayText: _overlay.text,
      ).hasEdits;

  /// Picking a real colour filter clears the effect (an effect's
  /// baked graph replaces the filter chain, never combines with it).
  void _selectFilter(VideoFilter f) {
    setState(() {
      _filter = f;
      if (f.ffmpegFilter != null) _effect = VideoEffects.all.first;
    });
  }

  /// Picking an effect resets the colour filter for the same reason.
  void _selectEffect(VideoEffect fx) {
    setState(() {
      _effect = fx;
      if (fx.ffmpegGraph != null) _filter = VideoFilters.all.first;
    });
  }

  Future<void> _pickMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      if (path == null) return;
      if (!mounted) return;
      setState(() {
        _musicPath = path;
        _musicName = path.split('/').last;
        _musicMode = MusicMode.replace;
      });
    } catch (e) {
      debugPrint('pickMusic failed: $e');
      if (mounted) {
        setState(
            () => _error = 'Could not pick a music file. Please try again.');
      }
    }
  }

  void _setMusicMode(MusicMode mode) {
    setState(() => _musicMode = mode);
    // Preview mirrors it: mute silences the preview, anything else
    // restores the original audio.
    _player?.setVolume(mode == MusicMode.mute ? 0 : 1);
  }

  Future<void> _post() async {
    final auth = AuthService.instance;
    if (!AuthService.firebaseReady || !auth.isSignedIn) {
      setState(() => _error = 'Please log in first to post.');
      return;
    }
    final player = _player;
    if (player == null) return;

    setState(() {
      _posting = true;
      _processing = _hasEdits;
      _progress = 0;
      _error = null;
    });

    File toUpload = File(widget.videoPath);
    try {
      if (_hasEdits) {
        toUpload = await VideoEditService.instance.processVideo(
          input: toUpload,
          options: VideoEditOptions(
            filter: _filter,
            effect: _effect,
            musicMode: _musicMode,
            musicPath: _musicPath,
            overlayText: _overlay.text,
            overlayPosition: _textPos,
          ),
          videoDuration: player.value.duration,
          videoHeight: player.value.size.height.round(),
        );
      }
    } catch (e) {
      // Processing failed: do NOT silently upload the unedited file.
      if (!mounted) return;
      setState(() {
        _posting = false;
        _processing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    setState(() => _processing = false);
    try {
      final url = await StorageService.instance.uploadVideo(
        toUpload,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      var soundName = _sound.text.trim();
      if (soundName.isEmpty && _musicMode == MusicMode.replace) {
        // Posting with picked music: name the sound after the track.
        soundName = (_musicName ?? 'Music')
            .replaceAll(RegExp(r'\.[^.]+$'), '')
            .replaceAll('_', ' ');
      }
      await FirestoreService.instance.addVideo(
        videoUrl: url,
        caption: _caption.text.trim(),
        uid: auth.uid!,
        username: auth.displayName,
        soundName: soundName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video posted successfully!')),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit video'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _post,
            child: const Text('Post',
                style: TextStyle(
                    color: AppTheme.accent2,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _preview(player),
                const SizedBox(height: 16),
                _sectionLabel('Filters'),
                const SizedBox(height: 8),
                _filtersRow(),
                const SizedBox(height: 16),
                _sectionLabel('Effects'),
                const SizedBox(height: 2),
                const Text('Effects apply when you post.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                _effectsRow(),
                const SizedBox(height: 16),
                _sectionLabel('Music'),
                const SizedBox(height: 8),
                _musicRow(),
                if (_musicMode == MusicMode.replace &&
                    _musicName != null) ...[
                  const SizedBox(height: 6),
                  Text('Music: $_musicName',
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                _sectionLabel('Text on video'),
                const SizedBox(height: 8),
                TextField(
                  controller: _overlay,
                  maxLength: 60,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Add text (optional)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                _positionRow(),
                const SizedBox(height: 16),
                _sectionLabel('Details'),
                const SizedBox(height: 8),
                TextField(
                  controller: _caption,
                  maxLines: 3,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption... #chaska',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sound,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: 'Sound name (optional)',
                    prefixIcon: Icon(Icons.music_note,
                        color: AppTheme.muted, size: 20),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.accent2, fontSize: 13)),
                ],
                if (_posting && !_processing) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppTheme.card,
                    color: AppTheme.accent,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading... ${(_progress * 100).toInt()}%',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _posting ? null : _post,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Post video'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent2),
                    SizedBox(height: 16),
                    Text('Processing…',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('Applying your edits to the video',
                        style:
                            TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
      );

  Widget _preview(VideoPlayerController? player) {
    Widget video;
    if (player == null || !player.value.isInitialized) {
      video = const Center(child: CircularProgressIndicator());
    } else {
      Widget inner = VideoPlayer(player);
      // A selected effect's grade replaces the filter preview;
      // structural effects have no honest matrix and show the
      // video unchanged — the baked result appears on post.
      final matrix = _effect.ffmpegGraph != null
          ? _effect.previewMatrix
          : _filter.previewMatrix;
      if (matrix != null) {
        inner = ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: inner,
        );
      }
      video = AspectRatio(
        aspectRatio: player.value.aspectRatio,
        child: inner,
      );
    }
    final text = _overlay.text.trim();
    return GestureDetector(
      onTap: () {
        final p = _player;
        if (p == null) return;
        p.value.isPlaying ? p.pause() : p.play();
        setState(() {});
      },
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: video),
            if (text.isNotEmpty)
              Align(
                alignment: switch (_textPos) {
                  OverlayPosition.top => const Alignment(0, -0.82),
                  OverlayPosition.center => Alignment.center,
                  OverlayPosition.bottom => const Alignment(0, 0.82),
                },
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4),
                      Shadow(
                          color: Colors.black,
                          offset: Offset(1.5, 1.5),
                          blurRadius: 2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: VideoFilters.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = VideoFilters.all[i];
          final selected = f.name == _filter.name;
          return ChoiceChip(
            label: Text(f.name),
            selected: selected,
            onSelected: _posting ? null : (_) => _selectFilter(f),
            selectedColor: AppTheme.accent,
            backgroundColor: AppTheme.card,
            labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.muted,
                fontWeight: FontWeight.w600),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  /// TikTok-panel style tiles: rounded square, emoji glyph, name
  /// underneath, violet highlight when selected. Single-select.
  Widget _effectsRow() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: VideoEffects.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final fx = VideoEffects.all[i];
          final selected = fx.name == _effect.name;
          return GestureDetector(
            onTap: _posting ? null : () => _selectEffect(fx),
            child: SizedBox(
              width: 62,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppTheme.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(fx.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fx.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: selected ? Colors.white : AppTheme.muted,
                      fontWeight: FontWeight.w600,
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

  Widget _musicRow() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Original sound'),
          selected: _musicMode == MusicMode.original,
          onSelected:
              _posting ? null : (_) => _setMusicMode(MusicMode.original),
          selectedColor: AppTheme.accent,
          backgroundColor: AppTheme.card,
          labelStyle: TextStyle(
              color: _musicMode == MusicMode.original
                  ? Colors.white
                  : AppTheme.muted,
              fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
        ChoiceChip(
          label: const Text('Mute'),
          selected: _musicMode == MusicMode.mute,
          onSelected: _posting
              ? null
              : (_) => _setMusicMode(MusicMode.mute),
          selectedColor: AppTheme.accent,
          backgroundColor: AppTheme.card,
          labelStyle: TextStyle(
              color: _musicMode == MusicMode.mute
                  ? Colors.white
                  : AppTheme.muted,
              fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
        ActionChip(
          avatar: const Icon(Icons.library_music_outlined,
              size: 18, color: Colors.white70),
          label: Text(_musicPath == null ? 'Pick music' : 'Change music'),
          onPressed: _posting ? null : _pickMusic,
          backgroundColor: _musicMode == MusicMode.replace
              ? AppTheme.accent
              : AppTheme.card,
          labelStyle: TextStyle(
              color: _musicMode == MusicMode.replace
                  ? Colors.white
                  : AppTheme.muted,
              fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      ],
    );
  }

  Widget _positionRow() {
    return Row(
      children: [
        const Text('Position:',
            style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        const SizedBox(width: 10),
        ...OverlayPosition.values.map((pos) {
          final selected = pos == _textPos;
          final label = switch (pos) {
            OverlayPosition.top => 'Top',
            OverlayPosition.center => 'Center',
            OverlayPosition.bottom => 'Bottom',
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected:
                  _posting ? null : (_) => setState(() => _textPos = pos),
              selectedColor: AppTheme.accent,
              backgroundColor: AppTheme.card,
              labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.muted,
                  fontWeight: FontWeight.w600),
              side: BorderSide.none,
            ),
          );
        }),
      ],
    );
  }
}
