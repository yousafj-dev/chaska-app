import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chaska/models/chaska_video.dart';
import 'package:chaska/models/chaska_comment.dart';
import 'package:chaska/models/chaska_story.dart';
import 'package:chaska/models/chaska_user.dart';
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

  CollectionReference get _users => _dbSafe.collection('users');

  CollectionReference get _stories => _dbSafe.collection('chaska_stories');

  CollectionReference _followingCol(String uid) =>
      _users.doc(uid).collection('following');

  /// Live profile of one user (`users/{uid}`). Emits null when the
  /// doc does not exist yet or Firebase is not ready.
  Stream<ChaskaUser?> userProfile(String uid) {
    try {
      return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? ChaskaUser.fromDoc(doc) : null);
    } catch (e) {
      debugPrint('userProfile failed: $e');
      return Stream.value(null);
    }
  }

  /// One-shot read of `users/{uid}`; null when missing/unavailable.
  Future<ChaskaUser?> getUserProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      return doc.exists ? ChaskaUser.fromDoc(doc) : null;
    } catch (e) {
      debugPrint('getUserProfile failed: $e');
      return null;
    }
  }

  /// Creates/merges `users/{uid}` with the editable profile fields.
  Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    required String photoUrl,
    required String bio,
  }) async {
    await _users.doc(uid).set(
      {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'bio': bio,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

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

  /// Videos uploaded by one user, newest first.
  ///
  /// NOTE: this intentionally does NOT use orderBy in the query —
  /// `where('uid') + orderBy('createdAt')` requires a composite
  /// index that does not exist in this project, which made the
  /// query fail and profiles show zero videos. The equality filter
  /// uses the automatic single-field index and sorting happens
  /// client-side instead.
  Stream<List<ChaskaVideo>> myVideos(String uid) {
    try {
      return _videos.where('uid', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(ChaskaVideo.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
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
    if (myUid == null) throw Exception('Please log in first.');
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
    if (myUid == null) throw Exception('Please log in first to comment.');
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('Write something first.');
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

  // ---------------------------------------------------------------
  // Stories
  // ---------------------------------------------------------------

  /// Latest stories (client filters to the last 24 hours).
  Stream<List<ChaskaStory>> storiesFeed({int limit = 100}) {
    try {
      return _stories
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ChaskaStory.fromDoc).toList());
    } catch (e) {
      debugPrint('storiesFeed failed: $e');
      return Stream.value(const []);
    }
  }

  /// Saves a story doc for the signed-in user. Name/photo come from
  /// the live profile doc when available, else the auth profile.
  Future<void> addStory({
    required String mediaUrl,
    required String mediaType,
  }) async {
    final auth = AuthService.instance;
    final uid = auth.uid;
    if (uid == null) throw Exception('Please log in first.');
    var name = auth.displayName;
    var photo = auth.photoUrl ?? '';
    final profile = await getUserProfile(uid);
    if (profile != null) {
      if (profile.displayName.isNotEmpty) name = profile.displayName;
      if (profile.photoUrl.isNotEmpty) photo = profile.photoUrl;
    }
    await _stories.add(ChaskaStory(
      id: '',
      uid: uid,
      userName: name,
      userPhoto: photo,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      createdAt: DateTime.now(),
    ).toMap());
  }

  // ---------------------------------------------------------------
  // Following (minimal follow system)
  // Data: users/{myUid}/following/{targetUid} = {createdAt}
  // ---------------------------------------------------------------

  /// Ids of everyone [uid] follows.
  Stream<List<String>> followingIds(String uid) {
    try {
      return _followingCol(uid)
          .snapshots()
          .map((s) => s.docs.map((d) => d.id).toList());
    } catch (e) {
      debugPrint('followingIds failed: $e');
      return Stream.value(const []);
    }
  }

  /// Whether the signed-in user follows [targetUid].
  Stream<bool> isFollowing(String targetUid) {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return Stream.value(false);
    try {
      return _followingCol(myUid)
          .doc(targetUid)
          .snapshots()
          .map((d) => d.exists);
    } catch (e) {
      debugPrint('isFollowing failed: $e');
      return Stream.value(false);
    }
  }

  /// Follow / unfollow [targetUid] for the signed-in user.
  Future<void> setFollowing(String targetUid, bool follow) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) throw Exception('Please log in first.');
    if (follow) {
      await _followingCol(myUid).doc(targetUid).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _followingCol(myUid).doc(targetUid).delete();
    }
  }

  /// How many creators [uid] follows.
  Stream<int> followingCount(String uid) {
    try {
      return _followingCol(uid)
          .snapshots()
          .map((s) => s.docs.length);
    } catch (e) {
      debugPrint('followingCount failed: $e');
      return Stream.value(0);
    }
  }

  /// Newest-first videos from the creators in [authorIds].
  /// Capped at the first 30 ids (Firestore whereIn limit) and
  /// sorted client-side to avoid needing a composite index.
  Stream<List<ChaskaVideo>> followingVideos(List<String> authorIds) {
    if (authorIds.isEmpty) return Stream.value(const []);
    final capped = authorIds.take(30).toList();
    try {
      return _videos.where('uid', whereIn: capped).snapshots().map((s) {
        final list = s.docs.map(ChaskaVideo.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (e) {
      debugPrint('followingVideos failed: $e');
      return Stream.value(const []);
    }
  }
}
