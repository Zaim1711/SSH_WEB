import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/ChatRoom.dart';
import 'package:ssh_web/Model/UserChat.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';
import 'package:ssh_web/Service/UserService.dart';
import 'package:ssh_web/View/AdminPage/ChatRoomService.dart';

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
  bool _isInChatScreen = false;
  String _lastSeen = '';
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;

  @override
  void initState() {
    super.initState();
    futureChatRooms = Future.value([]);
    _focusNode.requestFocus();
    _scrollToBottom();
    decodeToken();
  }

  Future<void> _updateUserStatus(bool isActive) async {
    if (selectedRoom == null) return;

    await FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(selectedRoom!.id.toString())
        .collection('user_status')
        .doc(userId)
        .set({
      'isActive': isActive,
      'lastActive': DateTime.now().toIso8601String(),
      'userId': userId,
    });
  }

// Tambahkan fungsi ini untuk memastikan pesan ditandai sebagai dibaca
  void _markMessageAsRead(String messageId) async {
    if (selectedRoom == null) return;

    await FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(selectedRoom!.id.toString())
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  void markAllMessagesAsRead() async {
    if (selectedRoom == null) return;

    try {
      final messagesQuery = FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(selectedRoom!.id.toString())
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false);

      final querySnapshot = await messagesQuery.get();

      if (querySnapshot.docs.isEmpty) {
        print('No messages need to be marked as read.');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('All messages marked as read!');
    } catch (error) {
      print('Failed to mark messages as read: $error');
    }
  }

  // Add method to format last seen time
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(lastSeen);
    }
  }

  // Modify the method when selecting a user
  void selectUser(User user, ChatRoom room) {
    setState(() {
      selectedUser = user;
      selectedRoom = room;
      _isInChatScreen = true;
    });

    // Start listening to user status
    _userStatusSubscription?.cancel();
    _userStatusSubscription = FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(selectedRoom!.id.toString())
        .collection('user_status')
        .doc(user.id.toString())
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _isInChatScreen = data['isActive'] ?? false;
          if (!_isInChatScreen && data['lastActive'] != null) {
            DateTime lastActive = DateTime.parse(data['lastActive']);
            _lastSeen = _formatLastSeen(lastActive);
          }
        });
      }
    });

    // Mark messages as read when selecting a chat
    markAllMessagesAsRead();
    _updateUserStatus(true);
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

  // Override untuk mendeteksi ketika widget dimuat dan dihancurkan
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _isInChatScreen = true;
    });
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

  Future<User> fetchUser(String receiverId) async {
    // Retrieve the access token from shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString(
        'accesToken'); // Ensure the key matches what you used to store the token

    // Make the GET request to fetch the user
    final response = await http.get(
      Uri.parse('http://localhost:8080/users/$receiverId'),
      headers: {
        'Authorization':
            'Bearer $accessToken', // Include the token in the headers
      },
    );

    // Check the response status
    if (response.statusCode == 200) {
      // Decode the JSON response and return a User object
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception(
          'Failed to load user'); // Handle error if the request fails
    }
  }

  void _showDeleteChatDialog(ChatRoom chatRoom) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Hapus Chat"),
          content: Text("Apakah Anda yakin ingin menghapus chat ini?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
              },
              child: Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                _deleteChatRoom(chatRoom); // Hapus chat room
                Navigator.pop(context); // Tutup dialog
              },
              child: Text("Hapus", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChatRoom(ChatRoom chatRoom) async {
    try {
      // Hapus chat room dari Firestore
      await FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(chatRoom.id.toString())
          .delete();

      // Update state untuk menghapus chat room dari daftar
      setState(() {
        futureChatRooms = futureChatRooms.then((chatRooms) {
          chatRooms.removeWhere((room) => room.id == chatRoom.id);
          return chatRooms;
        });
      });

      // Tampilkan notifikasi
      showNotification("Chat berhasil dihapus");
    } catch (error) {
      print("Gagal menghapus chat: $error");
      showNotification("Gagal menghapus chat");
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _updateUserStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error : ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('Belum ada chat'));
                      }
                      List<ChatRoom> chatRooms = snapshot.data!;

                      return ListView.builder(
                          itemCount: chatRooms.length,
                          itemBuilder: (context, index) {
                            String targetUserId =
                                chatRooms[index].receiverId == userId
                                    ? chatRooms[index].senderId!
                                    : (chatRooms[index].receiverId!);
                            return FutureBuilder<User>(
                                future: fetchUser(targetUserId),
                                builder: (context, userSnapshot) {
                                  if (userSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const ListTile(
                                      title: Text('Loading...'),
                                    );
                                  } else if (userSnapshot.hasError) {
                                    return ListTile(
                                      title:
                                          Text('Error ${userSnapshot.error}'),
                                    );
                                  } else if (!userSnapshot.hasData) {
                                    return const ListTile(
                                      title: Text('User tidak ditemukan'),
                                    );
                                  }
                                  User user = userSnapshot.data!;
                                  return GestureDetector(
                                    onLongPress: () {
                                      _showDeleteChatDialog(chatRooms[index]);
                                    },
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        radius: 20,
                                        child: Text(
                                          user.username[0].toUpperCase(),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      title: Text(user.email ??
                                          "Pengguna tidak diketahui"),
                                      onTap: () {
                                        setState(
                                          () {
                                            selectedUser = userSnapshot.data;
                                            selectedRoom = snapshot.data![
                                                index]; // Set the selectedRoom
                                            selectUser(userSnapshot.data!,
                                                snapshot.data![index]);
                                          },
                                        );
                                      },
                                    ),
                                  );
                                });
                          });
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
                            Text(
                              selectedUser!.username,
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isInChatScreen
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _isInChatScreen
                                  ? 'Sedang didalam obrolan'
                                  : 'Last seen $_lastSeen',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
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

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToBottom();
                            });

                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                var messageData = snapshot.data!.docs[index]
                                    .data() as Map<String, dynamic>;
                                return MessageBubble(
                                  message: messageData['messageContent'],
                                  isSender: messageData['senderId'] == userId,
                                  timestamp:
                                      DateTime.parse(messageData['timestamp']),
                                  isRead: messageData['isRead'] ??
                                      false, // Pastikan mengambil status isRead
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

// Update MessageBubble widget
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final DateTime timestamp;
  final bool isRead;

  MessageBubble({
    required this.message,
    required this.isSender,
    required this.timestamp,
    required this.isRead, // Ubah default value menjadi required
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSender ? Colors.white70 : Colors.grey,
                  ),
                ),
                if (isSender) ...[
                  SizedBox(width: 4),
                  Icon(
                    isRead
                        ? Icons.done_all
                        : Icons
                            .done, // Menggunakan icon untuk visual yang lebih baik
                    size: 16,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
