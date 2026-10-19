import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/models/chaska_comment.dart';
import 'package:chaska/services/auth_service.dart';

/// Firestore access for videos, likes and comments.
/// Every method throws [AuthService.offlineMsg] when Firebase is not
/// ready, so callers can show one friendly message instead of raw errors.
class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore? _db;

  FirebaseFirestore get _dbSafe {
    if (!AuthService.firebaseReady) throw Exception(AuthService.offlineMsg);
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  CollectionReference get _videos => _dbSafe.collection('chaska_videos');

  /// Newest-first video feed.
  Stream<List<ChaskaVideo>> videoFeed({int limit = 30}) {
    try {
      return _videos
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ChaskaVideo.fromDoc).toList());
    } catch (e) {
      debugPrint('videoFeed failed: $e');
      return Stream.value(const []);
    }
  }

  /// Videos uploaded by one user.
  Stream<List<ChaskaVideo>> myVideos(String uid) {
    try {
      return _videos
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(ChaskaVideo.fromDoc).toList());
    } catch (e) {
      debugPrint('myVideos failed: $e');
      return Stream.value(const []);
    }
  }

  Future<String> addVideo({
    required String videoUrl,
    required String caption,
    required String uid,
    required String username,
  }) async {
    final doc = await _videos.add(ChaskaVideo(
      id: '',
      videoUrl: videoUrl,
      caption: caption,
      uid: uid,
      username: username,
      createdAt: DateTime.now(),
    ).toMap());
    return doc.id;
  }

  /// Toggle like for the current user. Returns the new liked state.
  Future<bool> toggleLike(ChaskaVideo video) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) throw Exception('Pehle login karo.');
    final ref = _videos.doc(video.id);
    final liked = video.likedByMe(myUid);
    try {
      if (liked) {
        await ref.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([myUid]),
        });
      } else {
        await ref.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([myUid]),
        });
      }
      return !liked;
    } catch (e) {
      debugPrint('toggleLike failed: $e');
      rethrow;
    }
  }

  Stream<List<ChaskaComment>> comments(String videoId) {
    try {
      return _videos
          .doc(videoId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map(ChaskaComment.fromDoc).toList());
    } catch (e) {
      debugPrint('comments failed: $e');
      return Stream.value(const []);
    }
  }

  Future<void> addComment({
    required String videoId,
    required String text,
  }) async {
    final auth = AuthService.instance;
    final myUid = auth.uid;
    if (myUid == null) throw Exception('Comment ke liye pehle login karo.');
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('Pehle kuch likho.');
    await _videos.doc(videoId).collection('comments').add(ChaskaComment(
          id: '',
          uid: myUid,
          username: auth.displayName,
          text: trimmed,
          createdAt: DateTime.now(),
        ).toMap());
    await _videos.doc(videoId).update({
      'commentCount': FieldValue.increment(1),
    });
  }
}
