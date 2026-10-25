import 'package:cloud_firestore/cloud_firestore.dart';

/// A Chaska user profile. Stored in `users/{uid}` and kept in sync
/// with the FirebaseAuth profile (display name + photo URL).
class ChaskaUser {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String bio;

  /// In-app notification preferences (Settings → Notifications).
  /// The Inbox list filters by these; absent fields mean "on".
  final bool notifLikes;
  final bool notifComments;
  final bool notifFollows;

  const ChaskaUser({
    required this.uid,
    this.displayName = '',
    this.photoUrl = '',
    this.bio = '',
    this.notifLikes = true,
    this.notifComments = true,
    this.notifFollows = true,
  });

  factory ChaskaUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ChaskaUser(
      uid: doc.id,
      displayName: (d['displayName'] ?? '') as String,
      photoUrl: (d['photoUrl'] ?? '') as String,
      bio: (d['bio'] ?? '') as String,
      notifLikes: (d['notifLikes'] as bool?) ?? true,
      notifComments: (d['notifComments'] as bool?) ?? true,
      notifFollows: (d['notifFollows'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'bio': bio,
      };
}
