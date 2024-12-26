import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/ChatRoom.dart';
import 'package:ssh_web/Model/UserChat.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';
import 'package:ssh_web/Service/UserService.dart';
import 'package:ssh_web/View/ChatRoomService.dart';

class AdminChatPage extends StatefulWidget {
  @override
  _AdminChatPageState createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  late Future<List<ChatRoom>> futureChatRooms;
  final List<String> messages = [];
  User? selectedUser;
  ChatRoom? selectedRoom;
  String userId = '';
  String userName = '';
  final TextEditingController _messageController = TextEditingController();
  bool showUserList = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  final NotificationService _notificationService = NotificationService();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    futureChatRooms = Future.value([]);
    _focusNode.requestFocus();
    decodeToken();
  }

  Future<void> createRoom(User user, String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken == null) {
      print('Access token is null');
      showNotification('Access token not found');
      return;
    }

    final url = Uri.parse("http://localhost:8080/api/chatrooms");
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'senderId': userId,
          'receiverId': user.id,
        }));

    if (response.statusCode == 201) {
    } else {
      if (response.statusCode == 409) {
        showNotification('Chat sudah ada.');
      } else {
        print('An error occurred: ${response.body}');
      }
    }
  }

  void showNotification(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> decodeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    if (accessToken != null) {
      Map<String, dynamic> payload = JwtDecoder.decode(accessToken);
      setState(() {
        userName = payload['sub'].split(',')[2];
        userId = payload['sub'].split(',')[0];
        futureChatRooms = ChatRoomService().fetchAllChatRooms(userId);
      });
    }
  }

  void sendMessage(String messageContent) {
    if (messageContent.isNotEmpty) {
      String messageId = FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(selectedRoom!.id.toString())
          .collection('messages')
          .doc()
          .id;

      Map<String, dynamic> message = {
        'messageId': messageId,
        'chatRoomId': selectedRoom!.id.toString(),
        'messageContent': messageContent,
        'senderId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      };

      FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(selectedRoom!.id.toString())
          .collection('messages')
          .doc(messageId)
          .set(message)
          .then((_) {
        print(
            'Message sent to Firestore successfully! Document ID: $messageId');

        // Kirim notifikasi ke pengguna lain
        String receiverId = selectedUser!.id
            .toString(); // Ganti dengan ID pengguna yang akan menerima notifikasi
        String senderName = userName;
        String chatRoomId = selectedRoom!.id.toString();
        print(userName);

        _notificationService.sendNotification(
          receiverId,
          senderName,
          messageContent,
        );

        _scrollToBottom();
      }).catchError((error) {
        print('Failed to send message to Firestore: $error');
      });

      _messageController.clear();
      _focusNode.requestFocus();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _showUserListDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: 300,
            height: 400,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Select User',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: FutureBuilder<List<User>>(
                    future: UserService().fetchUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      print(snapshot);
                      if (!snapshot.hasData) return const SizedBox();

                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final user = snapshot.data![index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.profileImage.isNotEmpty
                                  ? NetworkImage(user.profileImage)
                                  : null,
                            ),
                            title: Text(user.email),
                            onTap: () {
                              createRoom(user, userId);
                              setState(() {
                                selectedUser = user;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left side - Chat List
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chats',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: _showUserListDialog,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<ChatRoom>>(
                    future: futureChatRooms,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return Center(child: CircularProgressIndicator());
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<User>(
                            future: UserService()
                                .fetchUser(snapshot.data![index].receiverId!),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) return SizedBox();
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      userSnapshot.data!.profileImage.isNotEmpty
                                          ? NetworkImage(
                                              userSnapshot.data!.profileImage)
                                          : null,
                                ),
                                title: Text(userSnapshot.data!.email),
                                selected:
                                    selectedUser?.id == userSnapshot.data!.id,
                                onTap: () {
                                  setState(() {
                                    selectedUser = userSnapshot.data;
                                    selectedRoom = snapshot
                                        .data![index]; // Set the selectedRoom
                                  });
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Right side - Chat Area
          Expanded(
            child: selectedRoom == null
                ? Center(child: Text('Select a user to start chatting'))
                : Column(
                    children: [
                      Container(
                        height: 60,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          children: [
                            Text(selectedUser!.username,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chatrooms')
                              .doc(selectedRoom!.id.toString())
                              .collection('messages')
                              .orderBy('timestamp')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return Center(child: CircularProgressIndicator());
                            return ListView.builder(
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                var message = snapshot.data!.docs[index];
                                return MessageBubble(
                                  message: message['messageContent'],
                                  isSender: message['senderId'] == userId,
                                  timestamp:
                                      DateTime.parse(message['timestamp']),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.attach_file),
                              onPressed: () {/* Handle attachment */},
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  sendMessage(value); // Send message on Enter
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.send),
                              onPressed: () {
                                String messageContent = _messageController.text;
                                sendMessage(messageContent);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final DateTime timestamp;

  MessageBubble({
    required this.message,
    required this.isSender,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSender ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isSender ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${timestamp.hour}:${timestamp.minute}',
              style: TextStyle(
                fontSize: 12,
                color: isSender ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
