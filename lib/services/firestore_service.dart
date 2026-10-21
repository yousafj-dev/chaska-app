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

  CollectionReference _favoritesCol(String uid) =>
      _users.doc(uid).collection('favorites');

  CollectionReference _repostsCol(String uid) =>
      _users.doc(uid).collection('reposts');

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
    String? soundName,
  }) async {
    final trimmedSound = soundName?.trim() ?? '';
    final doc = await _videos.add(ChaskaVideo(
      id: '',
      videoUrl: videoUrl,
      caption: caption,
      uid: uid,
      username: username,
      soundName:
          trimmedSound.isEmpty ? 'Original sound' : trimmedSound,
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

  // ---------------------------------------------------------------
  // Favorites
  // Data: users/{myUid}/favorites/{videoId} = {videoId, createdAt}
  // ---------------------------------------------------------------

  /// Whether the signed-in user has favorited [videoId].
  Stream<bool> isFavorite(String videoId) {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return Stream.value(false);
    try {
      return _favoritesCol(myUid)
          .doc(videoId)
          .snapshots()
          .map((d) => d.exists);
    } catch (e) {
      debugPrint('isFavorite failed: $e');
      return Stream.value(false);
    }
  }

  /// Toggle favorite for the signed-in user. Returns the new state.
  Future<bool> toggleFavorite(ChaskaVideo video) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) throw Exception('Please log in first.');
    final ref = _favoritesCol(myUid).doc(video.id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set({
      'videoId': video.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Videos the user favorited, newest favorite first. Ids come from
  /// the favorites subcollection and are resolved to video docs;
  /// favorites whose video was deleted are skipped. Sorted
  /// client-side to avoid needing a composite index.
  Stream<List<ChaskaVideo>> favoriteVideos(String uid) {
    try {
      return _favoritesCol(uid).snapshots().asyncMap((s) async {
        final docs = s.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>?)?['createdAt'];
            final tb = (b.data() as Map<String, dynamic>?)?['createdAt'];
            final da = ta is Timestamp ? ta.toDate() : DateTime(0);
            final db = tb is Timestamp ? tb.toDate() : DateTime(0);
            return db.compareTo(da);
          });
        final out = <ChaskaVideo>[];
        for (final d in docs) {
          final vdoc = await _videos.doc(d.id).get();
          if (vdoc.exists) out.add(ChaskaVideo.fromDoc(vdoc));
        }
        return out;
      });
    } catch (e) {
      debugPrint('favoriteVideos failed: $e');
      return Stream.value(const []);
    }
  }

  // ---------------------------------------------------------------
  // Reposts
  // Data: users/{myUid}/reposts/{videoId} = {videoId, createdAt}
  // plus a repostCount counter on the video doc itself.
  // ---------------------------------------------------------------

  /// Whether the signed-in user has reposted [videoId].
  Stream<bool> isReposted(String videoId) {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return Stream.value(false);
    try {
      return _repostsCol(myUid)
          .doc(videoId)
          .snapshots()
          .map((d) => d.exists);
    } catch (e) {
      debugPrint('isReposted failed: $e');
      return Stream.value(false);
    }
  }

  /// Toggle repost for the signed-in user: writes/removes the
  /// repost doc and adjusts the video's repostCount.
  /// Returns the new reposted state.
  Future<bool> toggleRepost(ChaskaVideo video) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) throw Exception('Please log in first.');
    final ref = _repostsCol(myUid).doc(video.id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      await _videos.doc(video.id).update({
        'repostCount': FieldValue.increment(-1),
      });
      return false;
    }
    await ref.set({
      'videoId': video.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _videos.doc(video.id).update({
      'repostCount': FieldValue.increment(1),
    });
    return true;
  }

  /// Videos the user reposted, newest repost first. Same
  /// resolve-by-id pattern as [favoriteVideos].
  Stream<List<ChaskaVideo>> repostedVideos(String uid) {
    try {
      return _repostsCol(uid).snapshots().asyncMap((s) async {
        final docs = s.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>?)?['createdAt'];
            final tb = (b.data() as Map<String, dynamic>?)?['createdAt'];
            final da = ta is Timestamp ? ta.toDate() : DateTime(0);
            final db = tb is Timestamp ? tb.toDate() : DateTime(0);
            return db.compareTo(da);
          });
        final out = <ChaskaVideo>[];
        for (final d in docs) {
          final vdoc = await _videos.doc(d.id).get();
          if (vdoc.exists) out.add(ChaskaVideo.fromDoc(vdoc));
        }
        return out;
      });
    } catch (e) {
      debugPrint('repostedVideos failed: $e');
      return Stream.value(const []);
    }
  }

  // ---------------------------------------------------------------
  // Delete own video
  // ---------------------------------------------------------------

  /// Permanently deletes one of the signed-in user's own videos:
  /// the video doc, its comments subcollection, and the user's own
  /// favorites/reposts entries for it. Likes live on the video doc
  /// itself (likedBy array), so they go away with the doc.
  ///
  /// NOTE: the Cloudinary media file is NOT deleted — uploads use an
  /// unsigned preset, which cannot delete media. Only the app record
  /// is removed, so the video disappears from the app everywhere.
  Future<void> deleteVideo(ChaskaVideo video) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) throw Exception('Please log in first.');
    if (video.uid != myUid) {
      throw Exception('You can only delete your own videos.');
    }
    final ref = _videos.doc(video.id);
    // Comments subcollection, best-effort, in pages of 200.
    while (true) {
      final qs = await ref.collection('comments').limit(200).get();
      if (qs.docs.isEmpty) break;
      final batch = _dbSafe.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (qs.docs.length < 200) break;
    }
    final batch = _dbSafe.batch();
    batch.delete(ref);
    batch.delete(_favoritesCol(myUid).doc(video.id));
    batch.delete(_repostsCol(myUid).doc(video.id));
    await batch.commit();
  }

  // ---------------------------------------------------------------
  // Sounds
  // ---------------------------------------------------------------

  /// All videos using [soundName], newest first. Equality filter +
  /// client-side sort to avoid needing a composite index.
  Stream<List<ChaskaVideo>> videosBySound(String soundName) {
    try {
      return _videos
          .where('soundName', isEqualTo: soundName)
          .snapshots()
          .map((s) {
        final list = s.docs.map(ChaskaVideo.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (e) {
      debugPrint('videosBySound failed: $e');
      return Stream.value(const []);
    }
  }
}
