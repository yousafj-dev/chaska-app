import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:chaska/services/auth_service.dart';

/// Uploads picked videos to Cloudinary (unsigned upload) and returns
/// the playable `secure_url`, which Firestore stores as the video URL.
///
/// Login and metadata still live in Firebase — only the video bytes
/// go to Cloudinary.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String _cloudName = 'q76vpymr';
  static const String _uploadPreset = 'lhmgywrj';
  static const String _folder = 'chaska_videos';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  /// Uploads [file] and returns its public Cloudinary URL.
  /// Calls [onProgress] with 0.0–1.0 as bytes transfer.
  /// Throws an [Exception] with a friendly Roman Urdu message on failure.
  Future<String> uploadVideo(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    if (!AuthService.firebaseReady) throw Exception(AuthService.offlineMsg);
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('Upload ke liye pehle login karo.');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'upload_preset': _uploadPreset,
      'folder': _folder,
    });

    try {
      final resp = await _dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      final url = resp.data?['secure_url'] as String?;
      if (resp.statusCode == 200 && url != null && url.isNotEmpty) {
        return url;
      }
      debugPrint('uploadVideo unexpected response: ${resp.statusCode}');
      throw Exception('Upload fail ho gaya, dobara koshish karo.');
    } on DioException catch (e) {
      debugPrint('uploadVideo failed: ${e.type}');
      if (e.response != null) {
        // Server replied with an error (e.g. bad preset) — not a network issue.
        throw Exception('Upload fail ho gaya, dobara koshish karo.');
      }
      throw Exception(
          'Internet masla — upload nahi ho saka, dobara koshish karo.');
    }
  }
}
