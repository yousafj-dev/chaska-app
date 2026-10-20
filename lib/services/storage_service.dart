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

  /// Turns a raw Firebase Storage error into a friendly Roman Urdu
  /// message the user can act on. Never leak raw exception text.
  static String _friendlyMessage(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'object-not-found':
        case 'bucket-not-found':
          return 'Storage abhi on nahi hua — pehle Firebase console se Storage on karo.';
        case 'unauthorized':
          return 'Upload ki ijazat nahi mili.';
        case 'canceled':
          return 'Upload cancel ho gayi, dobara try karo.';
        case 'network-request-failed':
          return 'Internet ka masla hai, dobara try karo.';
      }
    }
    return 'Upload nahi ho saki, dobara try karo.';
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
      // Progress listener: guarded so listener errors never surface as
      // unhandled async errors — it only forwards progress.
      final sub = task.snapshotEvents.listen(
        (s) {
          final total = s.totalBytes;
          if (total > 0) onProgress?.call(s.bytesTransferred / total);
        },
        onError: (Object e) {
          debugPrint('upload progress listener error (ignored): $e');
        },
      );
      try {
        await task;
      } finally {
        await sub.cancel();
      }
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('uploadVideo failed: $e');
      throw Exception(_friendlyMessage(e));
    }
  }
}
