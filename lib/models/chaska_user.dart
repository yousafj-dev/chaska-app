import 'package:cloud_firestore/cloud_firestore.dart';

/// A Chaska user profile. Stored in `users/{uid}` and kept in sync
/// with the FirebaseAuth profile (display name + photo URL).
class ChaskaUser {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String bio;

  const ChaskaUser({
    required this.uid,
    this.displayName = '',
    this.photoUrl = '',
    this.bio = '',
  });

  factory ChaskaUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ChaskaUser(
      uid: doc.id,
      displayName: (d['displayName'] ?? '') as String,
      photoUrl: (d['photoUrl'] ?? '') as String,
      bio: (d['bio'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'bio': bio,
      };
}
