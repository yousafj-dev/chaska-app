import 'package:cloud_firestore/cloud_firestore.dart';

/// One in-app notification, stored in `chaska_notifications`.
/// Written by the actor's client when someone likes, comments on
/// or follows an account; read by the recipient's Inbox.
class ChaskaNotification {
  final String id;
  final String fromUid;
  final String fromName;
  final String type; // 'like' | 'comment' | 'follow'
  final String videoId;
  final String text;
  final bool read;
  final DateTime createdAt;

  const ChaskaNotification({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.type,
    this.videoId = '',
    this.text = '',
    this.read = false,
    required this.createdAt,
  });

  factory ChaskaNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final raw = d['createdAt'];
    return ChaskaNotification(
      id: doc.id,
      fromUid: (d['fromUid'] ?? '') as String,
      fromName: (d['fromName'] ?? 'chaska_user') as String,
      type: (d['type'] ?? '') as String,
      videoId: (d['videoId'] ?? '') as String,
      text: (d['text'] ?? '') as String,
      read: (d['read'] as bool?) ?? false,
      createdAt: raw is Timestamp ? raw.toDate() : DateTime.now(),
    );
  }
}
