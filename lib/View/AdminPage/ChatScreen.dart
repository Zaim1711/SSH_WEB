import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/UserChat.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';
// Pastikan untuk mengimpor NotificationService

class Chatscreen extends StatefulWidget {
  final User user;
  final String? roomId;
  final String senderId;

  Chatscreen({
    Key? key,
    required this.user,
    this.roomId,
    required this.senderId,
  }) : super(key: key);

  @override
  _ChatscreenState createState() => _ChatscreenState();
}

class _ChatscreenState extends State<Chatscreen> {
  final TextEditingController _messageInputController = TextEditingController();
  final List<String> messages = [];
  Map<String, dynamic> payload = {};
  String userName = '';
  String userId = '';
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  final ScrollController _scrollController = ScrollController();
  final NotificationService _notificationService = NotificationService();
  final ImagePicker _picker = ImagePicker();
  bool _isPickingMedia = false;
  String? currentRoomId;
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;
  bool _isInChatScreen = false;
  String _lastSeen = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    currentRoomId = widget.roomId;
    _getUserIdFromToken();
    if (currentRoomId != null) {
      listenForMessages();
      markAllMessagesAsRead();
      _updateUserStatus(true); // Set status user aktif
    }
    _notificationService.init(); // Inisialisasi notifikasi
    _notificationService.configureFCM(); // Konfigurasi FCM
  }

  Future<void> _updateUserStatus(bool isActive) async {
    if (currentRoomId == null) return;

    await FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(currentRoomId)
        .collection('user_status')
        .doc(widget.senderId)
        .set({
      'isActive': isActive,
      'lastActive': DateTime.now().toIso8601String(),
      'userId': widget.senderId,
    });
  }

  Future<void> _getUserIdFromToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      payload = JwtDecoder.decode(accessToken);
      String name = payload['sub'].split(',')[2];
      String id = payload['sub'].split(',')[0];
      // Mengambil nilai 'name' dari token JWT
      setState(() {
        userName = name;
        userId = id;
      });
    }
  }

  Future<String> createRoom() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken == null) {
      throw Exception('Access token not found');
    }

    final url = Uri.parse("http://localhost:8080/api/chatrooms");
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'senderId': widget.senderId,
        'receiverId': widget.user.id,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id'].toString();
    } else if (response.statusCode == 409) {
      showNotification(
          'chat sudah ada'); // If room already exists, fetch the existing room ID
      final data = jsonDecode(response.body);
      return data['roomId']
          .toString(); // Assume the API returns the existing roomId
    } else {
      showNotification('Chat sudah dengan ${widget.user.username} sudah ada');
      return '';
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

  Future<void> _pickMedia() async {
    if (_isPickingMedia) return;

    _isPickingMedia = true;

    // Tampilkan dialog untuk memilih antara kamera atau galeri
    final String? source = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pilih Sumber Gambar'),
          actions: <Widget>[
            TextButton(
              child: Text('Ambil Foto'),
              onPressed: () {
                Navigator.of(context).pop('camera'); // Mengembalikan 'camera'
              },
            ),
            TextButton(
              child: Text('Pilih dari Galeri'),
              onPressed: () {
                Navigator.of(context).pop('gallery'); // Mengembalikan 'gallery'
              },
            ),
          ],
        );
      },
    );

    if (source == null) {
      _isPickingMedia =
          false; // Reset status jika tidak ada sumber yang dipilih
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        _showImagePreviewDialog(file);
      }
    } catch (e) {
      print('Error picking media: $e');
    } finally {
      _isPickingMedia = false;
    }
  }

  void listenForMessages() {
    _messageSubscription = FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(currentRoomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          String messageContent = data['messageContent'];
          String senderId = data['senderId'];
          String timestamp = data['timestamp'];
          String chatRoomId = data['chatRoomId']; // Masih ada di sini
          bool isRead = data['isRead'] ?? false;
          if (data['senderId'] != widget.senderId && _isInChatScreen) {
            _markMessageAsRead(doc.doc.id);
          }
          setState(() {
            messages.add(
                "$messageContent - ${DateFormat('HH:mm').format(DateTime.parse(timestamp))} - $senderId - Chat Room: $chatRoomId - ${isRead ? '✔️' : '✖️'}");
          });
          _scrollToBottom();
        }
      }
    });
    _userStatusSubscription = FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(currentRoomId)
        .collection('user_status')
        .doc(widget.user.id.toString())
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

        // Existing code for updating unread messages
        if (_isInChatScreen) {
          _updateUnreadMessages();
        }
      }
    });
  }

  // Fungsi helper untuk memformat waktu terakhir aktif
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(lastSeen);
    }
  }

  // Fungsi untuk update pesan yang belum dibaca
  Future<void> _updateUnreadMessages() async {
    final unreadMessages = await FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(currentRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.senderId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Fungsi untuk menandai satu pesan sebagai dibaca
  Future<void> _markMessageAsRead(String messageId) async {
    await FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(currentRoomId)
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  Future<void> sendMessage(String messageContent) async {
    if (messageContent.isEmpty) return;

    try {
      // If no room exists, create one
      if (currentRoomId == null) {
        currentRoomId = await createRoom();
        // Start listening for messages after room is created
        listenForMessages();
      }

      String messageId = FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(currentRoomId)
          .collection('messages')
          .doc()
          .id;

      Map<String, dynamic> message = {
        'messageId': messageId,
        'chatRoomId': currentRoomId,
        'messageContent': messageContent,
        'senderId': widget.senderId,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      };

      await FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(currentRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message);

      String receiverId = widget.user.id.toString();
      _notificationService.sendNotification(
        receiverId,
        userName,
        messageContent,
      );

      _scrollToBottom();
      _messageInputController.clear();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  void _showImagePreviewDialog(File file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Preview Gambar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(file), // Tampilkan gambar
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {},
              child: Text('Kirim'),
            ),
            TextButton(
              onPressed: () {
                // Tutup dialog tanpa mengirim
                Navigator.of(context).pop(); // Tutup dialog
                _isPickingMedia = false; // Reset status setelah dialog ditutup
              },
              child: Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _updateUserStatus(false); // Set status user tidak aktif
    _messageInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Override untuk mendeteksi ketika widget dimuat dan dihancurkan
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _isInChatScreen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 30,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                widget.user.username[0].toUpperCase(),
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.username,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isInChatScreen ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInChatScreen
                            ? 'Sedang dalam obrolan'
                            : 'Terakhir dilihat $_lastSeen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.attach_file),
            onPressed: _pickMedia,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: _buildMessageList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageInputController,
                    decoration: const InputDecoration(
                      labelText: 'Masukkan pesan',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    String messageContent = _messageInputController.text;
                    sendMessage(messageContent);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (currentRoomId == null) {
      return Center(child: Text('Belum ada pesan.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(currentRoomId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Belum ada pesan.'));
        }

        final messages = snapshot.data!.docs;
        List<Widget> messageWidgets = [];
        DateTime? previousDate;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        for (int index = 0; index < messages.length; index++) {
          final messageData = messages[index].data() as Map<String, dynamic>;
          final messageContent = messageData['messageContent'];
          final senderId = messageData['senderId'];
          final timestamp = DateTime.parse(messageData['timestamp']);
          final isRead = messageData['isRead'] ?? false;

          // Check if we need to add a date header
          if (previousDate == null || !_isSameDay(previousDate, timestamp)) {
            messageWidgets.add(_buildDateHeader(timestamp));
          }
          previousDate = timestamp;

          // Add the message bubble
          final readIndicator =
              senderId == widget.senderId ? (isRead ? '✔✔' : '✔') : '';

          messageWidgets.add(
            Align(
              alignment: senderId == widget.senderId
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: MessageBubble(
                message:
                    "$messageContent - ${DateFormat('HH:mm').format(timestamp)} $readIndicator",
                isSender: senderId == widget.senderId,
              ),
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          children: messageWidgets,
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateHeader(DateTime timestamp) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    String dateText;

    if (_isSameDay(timestamp, now)) {
      dateText = 'Hari Ini';
    } else if (_isSameDay(timestamp, yesterday)) {
      dateText = 'Kemarin';
    } else {
      dateText = DateFormat('d MMMM yyyy', 'id_ID').format(timestamp);
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void markAllMessagesAsRead() async {
    try {
      final messagesQuery = FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(currentRoomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: widget.senderId)
          .where('isRead', isEqualTo: false);

      final querySnapshot = await messagesQuery.get();

      if (querySnapshot.docs.isEmpty) {
        print('Tidak ada pesan yang perlu ditandai sebagai telah dibaca.');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('Semua pesan telah ditandai sebagai dibaca!');
    } catch (error) {
      print('Gagal menandai pesan sebagai dibaca: $error');
    }
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isSender;

  const MessageBubble({Key? key, required this.message, required this.isSender})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isSender ? Colors.blueAccent : Colors.grey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.white),
        softWrap: true,
      ),
    );
  }
}
