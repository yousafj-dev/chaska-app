import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// A named video filter. [ffmpegFilter] is the `-vf` fragment baked into
/// the posted video; [previewMatrix] is the ColorFilter approximation
/// shown live on the edit screen. `null` ffmpegFilter = no processing.
class VideoFilter {
  final String name;
  final String? ffmpegFilter;
  final List<double>? previewMatrix;

  const VideoFilter(this.name, this.ffmpegFilter, this.previewMatrix);
}

/// Where the overlay text sits on the frame.
enum OverlayPosition { top, center, bottom }

/// What happens to the audio on post.
enum MusicMode { original, mute, replace }

/// The edits chosen on the edit screen.
class VideoEditOptions {
  final VideoFilter filter;
  final MusicMode musicMode;

  /// Audio file path when [musicMode] is [MusicMode.replace].
  final String? musicPath;
  final String overlayText;
  final OverlayPosition overlayPosition;

  const VideoEditOptions({
    required this.filter,
    this.musicMode = MusicMode.original,
    this.musicPath,
    this.overlayText = '',
    this.overlayPosition = OverlayPosition.bottom,
  });

  bool get hasEdits =>
      filter.ffmpegFilter != null ||
      musicMode != MusicMode.original ||
      overlayText.trim().isNotEmpty;
}

class VideoFilters {
  VideoFilters._();

  // Saturation matrix for a given saturation level (0 = greyscale).
  static List<double> _sat(double s) => [
        0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0,
        0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
        0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
        0, 0, 0, 1, 0,
      ];

  // Contrast c around mid-grey combined with a brightness offset.
  static const List<double> _noirPreview = [
    0.276, 0.928, 0.094, 0, -34,
    0.276, 0.928, 0.094, 0, -34,
    0.276, 0.928, 0.094, 0, -34,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _fadePreview = [
    0.62, 0.28, 0.03, 0, 34,
    0.16, 0.68, 0.05, 0, 34,
    0.16, 0.27, 0.76, 0, 34,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _warmPreview = [
    1.16, 0.02, 0, 0, 4,
    0, 1.03, 0, 0, 0,
    0, 0, 0.84, 0, -4,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _coolPreview = [
    0.86, 0, 0, 0, -4,
    0, 1.0, 0.02, 0, 2,
    0, 0.03, 1.16, 0, 8,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _vintagePreview = [
    0.86, 0.28, 0.06, 0, 10,
    0.12, 0.72, 0.10, 0, 4,
    0.22, 0.24, 0.52, 0, -8,
    0, 0, 0, 1, 0,
  ];

  static List<VideoFilter> get all => [
        const VideoFilter('Normal', null, null),
        VideoFilter('Warm',
            'eq=saturation=1.12:brightness=0.02,'
            'colorbalance=rs=0.13:gs=0.03:bs=-0.13:rm=0.08:bm=-0.08',
            _warmPreview),
        VideoFilter('Cool',
            'eq=saturation=1.05,'
            'colorbalance=rs=-0.13:gs=-0.02:bs=0.15:rm=-0.06:bm=0.08',
            _coolPreview),
        VideoFilter('Vivid', 'eq=saturation=1.45:contrast=1.12', _sat(1.45)),
        VideoFilter('Vintage',
            'eq=saturation=0.7:contrast=0.94:brightness=0.05,'
            'colorbalance=rs=0.08:gs=0.02:bs=-0.12,vignette=PI/5',
            _vintagePreview),
        VideoFilter('B&W', 'eq=saturation=0', _sat(0)),
        VideoFilter(
            'Fade', 'eq=contrast=0.84:brightness=0.13:saturation=0.78',
            _fadePreview),
        VideoFilter('Noir',
            'eq=saturation=0.04:contrast=1.32:brightness=-0.02,'
            'vignette=PI/3.2',
            _noirPreview),
      ];
}

/// Runs FFmpeg (via ffmpeg_kit_flutter_new) to bake the chosen filter,
/// music change and text overlay into a NEW mp4. The original file is
/// never modified. Throws an [Exception] with a friendly English
/// message when processing fails — callers must NOT fall back to
/// uploading the unedited file in that case.
class VideoEditService {
  VideoEditService._();
  static final VideoEditService instance = VideoEditService._();

  static const _failMsg =
      'Video processing failed. Please try again with different edits.';

  Future<File> processVideo({
    required File input,
    required VideoEditOptions options,
    required Duration videoDuration,
    required int videoHeight,
  }) async {
    final tmp = await getTemporaryDirectory();
    final out = File(
        '${tmp.path}/chaska_edit_${DateTime.now().millisecondsSinceEpoch}.mp4');

    // Build the video filter chain: colour filter first, then text.
    final vfParts = <String>[];
    if (options.filter.ffmpegFilter != null) {
      vfParts.add(options.filter.ffmpegFilter!);
    }
    final text = options.overlayText.trim();
    if (text.isNotEmpty) {
      final font = await _fontFile();
      final y = switch (options.overlayPosition) {
        OverlayPosition.top => 'h*0.06',
        OverlayPosition.center => '(h-text_h)/2',
        OverlayPosition.bottom => 'h-text_h-h*0.09',
      };
      final fontSize = (videoHeight / 17).round().clamp(24, 96);
      vfParts.add("drawtext=fontfile=${font.path}"
          ":text='${_sanitize(text)}'"
          ':fontcolor=white:fontsize=$fontSize'
          ':borderw=3:bordercolor=black'
          ':x=(w-text_w)/2:y=$y');
    }
    final vf = vfParts.isEmpty ? null : vfParts.join(',');

    final args = <String>['-y', '-i', input.path];
    switch (options.musicMode) {
      case MusicMode.original:
        if (vf != null) args.addAll(['-vf', vf]);
        args.addAll([
          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
          '-c:a', 'aac', '-b:a', '128k',
        ]);
        break;
      case MusicMode.mute:
        if (vf != null) {
          args.addAll(['-vf', vf, '-c:v', 'libx264', '-preset', 'veryfast',
              '-crf', '23']);
        } else {
          args.addAll(['-c:v', 'copy']);
        }
        args.add('-an');
        break;
      case MusicMode.replace:
        final dur = videoDuration.inMilliseconds / 1000.0;
        final fadeStart = (dur - 2).clamp(0.0, dur);
        args.addAll(['-stream_loop', '-1', '-i', options.musicPath!]);
        if (vf != null) args.addAll(['-vf', vf]);
        args.addAll([
          '-map', '0:v:0', '-map', '1:a:0',
          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
          '-af', 'afade=t=out:st=$fadeStart:d=2',
          '-c:a', 'aac', '-b:a', '160k',
          '-shortest',
        ]);
        break;
    }
    args.addAll(['-movflags', '+faststart', out.path]);

    debugPrint('FFmpeg args: ${args.join(' ')}');
    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc) || !await out.exists()) {
      final log = await session.getOutput();
      debugPrint('FFmpeg failed (rc=$rc): $log');
      throw Exception(_failMsg);
    }
    return out;
  }

  /// drawtext treats : ' \ % [ ] , ; as syntax. Strip them so the
  /// filter graph can never break on user text.
  String _sanitize(String text) => text
      .replaceAll(RegExp(r'''[:'\\%\[\],;"]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<File> _fontFile() async {
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/DejaVuSans-Bold.ttf');
    if (!await f.exists()) {
      final data = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
      await f.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    return f;
  }
}
