import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chaska/models/chaska_video.dart';

/// One video saved on the device for offline watching.
class OfflineVideo {
  final String videoId;
  final String caption;
  final String username;
  final String thumbUrl;
  final String filePath;
  final DateTime savedAt;

  const OfflineVideo({
    required this.videoId,
    required this.caption,
    required this.username,
    required this.thumbUrl,
    required this.filePath,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'caption': caption,
        'username': username,
        'thumbUrl': thumbUrl,
        'filePath': filePath,
        'savedAt': savedAt.toIso8601String(),
      };

  factory OfflineVideo.fromJson(Map<String, dynamic> j) => OfflineVideo(
        videoId: (j['videoId'] ?? '') as String,
        caption: (j['caption'] ?? '') as String,
        username: (j['username'] ?? '') as String,
        thumbUrl: (j['thumbUrl'] ?? '') as String,
        filePath: (j['filePath'] ?? '') as String,
        savedAt:
            DateTime.tryParse((j['savedAt'] ?? '') as String) ??
                DateTime.now(),
      );
}

/// Downloads feed videos into the app's own documents folder so
/// they can be watched with no connection (Profile → Offline
/// videos). Files live under `<documents>/offline_videos/` and the
/// metadata list in `<documents>/offline_videos/meta.json`. App
/// documents need no storage permission on Android.
class OfflineService {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  final Dio _dio = Dio();

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/offline_videos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _metaFile() async =>
      File('${(await _dir()).path}/meta.json');

  Future<List<OfflineVideo>> list() async {
    try {
      final f = await _metaFile();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      final entries = decoded
          .map((e) =>
              OfflineVideo.fromJson(e as Map<String, dynamic>))
          .where((e) => File(e.filePath).existsSync())
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return entries;
    } catch (e) {
      debugPrint('OfflineService.list failed: $e');
      return [];
    }
  }

  Future<void> _saveAll(List<OfflineVideo> entries) async {
    final f = await _metaFile();
    await f.writeAsString(
        jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<bool> isDownloaded(String videoId) async {
    final entries = await list();
    return entries.any((e) => e.videoId == videoId);
  }

  /// Downloads [video]'s mp4, reporting 0..1 progress. Returns the
  /// saved entry. Throws a friendly [Exception] on failure.
  Future<OfflineVideo> download(
    ChaskaVideo video, {
    void Function(double progress)? onProgress,
  }) async {
    if (video.videoUrl.isEmpty) {
      throw Exception('This video cannot be downloaded.');
    }
    final existing = await list();
    final dupe = existing.where((e) => e.videoId == video.id);
    if (dupe.isNotEmpty) return dupe.first;
    final dir = await _dir();
    final path = '${dir.path}/${video.id}.mp4';
    try {
      await _dio.download(
        video.videoUrl,
        path,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) {
            onProgress(received / total);
          }
        },
      );
    } catch (e) {
      debugPrint('OfflineService.download failed: $e');
      final partial = File(path);
      if (await partial.exists()) await partial.delete();
      throw Exception(
          'Download failed. Please check your connection and try again.');
    }
    final entry = OfflineVideo(
      videoId: video.id,
      caption: video.caption,
      username: video.username,
      thumbUrl: video.thumbUrl,
      filePath: path,
      savedAt: DateTime.now(),
    );
    await _saveAll([entry, ...existing]);
    return entry;
  }

  Future<void> delete(OfflineVideo entry) async {
    try {
      final f = File(entry.filePath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('OfflineService.delete file failed: $e');
    }
    final entries = await list();
    entries.removeWhere((e) => e.videoId == entry.videoId);
    await _saveAll(entries);
  }
}
