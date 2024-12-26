class SentMessage {
  final int id;
  final String content;
  final String senderId;
  final String timestamp;

  SentMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.timestamp,
  });

  factory SentMessage.fromJson(Map<String, dynamic> json) {
    return SentMessage(
      id: json['id'],
      content: json['content'],
      senderId: json['senderId'],
      timestamp: json['timestamp'],
    );
  }
}
