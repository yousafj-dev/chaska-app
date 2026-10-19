import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:chaska/services/auth_service.dart';

/// Uploads picked videos to Firebase Storage under
/// `chaska_videos/{uid}/{timestamp}.mp4`.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  FirebaseStorage? _storage;

  FirebaseStorage get _storageSafe {
    if (!AuthService.firebaseReady) throw Exception(AuthService.offlineMsg);
    _storage ??= FirebaseStorage.instance;
    return _storage!;
  }

  /// Uploads [file] and returns its public download URL.
  /// Calls [onProgress] with 0.0–1.0 as bytes transfer.
  Future<String> uploadVideo(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('Upload ke liye pehle login karo.');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storageSafe.ref('chaska_videos/$uid/$ts.mp4');
    try {
      final task = ref.putFile(file);
      task.snapshotEvents.listen((s) {
        final total = s.totalBytes;
        if (total > 0) onProgress?.call(s.bytesTransferred / total);
      });
      await task;
      return ref.getDownloadURL();
    } catch (e) {
      debugPrint('uploadVideo failed: $e');
      rethrow;
    }
  }
}
