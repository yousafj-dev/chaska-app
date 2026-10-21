import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 24-hour story. Stored in `chaska_stories`.
class ChaskaStory {
  final String id;
  final String uid;
  final String userName;
  final String userPhoto;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final DateTime createdAt;

  const ChaskaStory({
    required this.id,
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
  });

  bool get isVideo => mediaType == 'video';

  /// Stories live for 24 hours.
  bool get isLive =>
      DateTime.now().difference(createdAt) < const Duration(hours: 24);

  factory ChaskaStory.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final raw = d['createdAt'];
    return ChaskaStory(
      id: doc.id,
      uid: (d['uid'] ?? '') as String,
      userName: (d['userName'] ?? 'chaska_user') as String,
      userPhoto: (d['userPhoto'] ?? '') as String,
      mediaUrl: (d['mediaUrl'] ?? '') as String,
      mediaType: (d['mediaType'] ?? 'image') as String,
      createdAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// All live stories of one user, oldest first (playback order).
class StoryGroup {
  final String uid;
  final String userName;
  final String userPhoto;
  final List<ChaskaStory> stories;

  const StoryGroup({
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.stories,
  });
}

/// Remembers which stories the current user has already viewed, so
/// the gradient ring can drop. Persisted in SharedPreferences.
class StoryViews {
  StoryViews._();

  static const _key = 'chaska_viewed_story_ids';
  static final Set<String> _viewed = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      _viewed.addAll(p.getStringList(_key) ?? const []);
    } catch (_) {}
  }

  static bool isViewed(String storyId) => _viewed.contains(storyId);

  static bool groupViewed(StoryGroup g) =>
      g.stories.every((s) => isViewed(s.id));

  static Future<void> markViewed(String storyId) async {
    if (!_viewed.add(storyId)) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, _viewed.toList());
    } catch (_) {}
  }
}
