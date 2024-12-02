class NotificationRequest {
  final String userId;
  final String title;
  final String body;
  final String? chatRoomId; // Menambahkan chatRoomId

  NotificationRequest({
    required this.userId,
    required this.title,
    required this.body,
    this.chatRoomId,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'chatRoomId': chatRoomId,
    };
  }
}
