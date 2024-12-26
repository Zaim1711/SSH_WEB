import 'package:ssh_web/Model/sentMessage.dart';

class ChatRoom {
  final int id;
  final String? senderId;
  final String? receiverId;
  final DateTime tanggal;
  final List<SentMessage> sentMessages;

  ChatRoom({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.tanggal,
    required this.sentMessages,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    var list = json['sentMessages'] as List;
    List<SentMessage> sentMessagesList =
        list.map((i) => SentMessage.fromJson(i)).toList();

    return ChatRoom(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      tanggal: DateTime.parse(json['tanggal']),
      sentMessages: sentMessagesList,
    );
  }
}
