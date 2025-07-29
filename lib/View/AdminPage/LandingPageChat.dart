import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Pastikan Anda memiliki paket ini
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/ChatRoom.dart';
import 'package:ssh_web/Model/UserChat.dart';
import 'package:ssh_web/Service/ChatRoomService.dart';
import 'package:ssh_web/Service/UserService.dart' as user_service;
import 'package:ssh_web/View/AdminPage/ChatScreen.dart';
import 'package:ssh_web/View/AdminPage/UserListChat.dart';

// Halaman utama untuk menampilkan chat rooms
class LandingPageChatRooms extends StatefulWidget {
  @override
  _LandingPageChatRoomsState createState() => _LandingPageChatRoomsState();
}

class _LandingPageChatRoomsState extends State<LandingPageChatRooms> {
  late Future<List<ChatRoom>>
      futureChatRooms; // Ubah menjadi Future<List<ChatRoom>>
  String userId = '';

  @override
  void initState() {
    super.initState();
    futureChatRooms =
        Future.value([]); // Inisialisasi dengan objek ChatRoom kosong
    decodeToken();
  }

  Future<void> decodeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      Map<String, dynamic> payload = JwtDecoder.decode(accessToken);
      setState(() {
        userId = payload['sub'].split(',')[0];
        futureChatRooms = ChatRoomService()
            .fetchAllChatRooms(userId); // Ambil daftar chat rooms
      });
    } else {
      print("Token not found.");
    }
  }

  void navigateToChatScreen(ChatRoom chatRoom) async {
    try {
      // Tentukan ID pengguna yang akan diambil berdasarkan userId
      String targetUserId = chatRoom.receiverId == userId
          ? chatRoom
              .senderId! // Jika receiverId sama dengan userId, ambil senderId
          : chatRoom.receiverId!; // Jika tidak, ambil receiverId

      // Ambil detail pengguna menggunakan targetUser Id
      User user = await user_service.UserService().fetchUser(targetUserId);

      String targetSenderId = chatRoom.receiverId == userId
          ? chatRoom.receiverId!
          : chatRoom.senderId!;

      // Ambil detail pengguna menggunakan senderId (selalu ambil senderId)
      User sender = await user_service.UserService().fetchUser(targetSenderId);
      print(
          'Navigating to chat screen with: roomId: ${chatRoom.id}, user: ${user.email}, senderId: $userId');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Chatscreen(
            user: user, // Kirim pengguna yang diambil
            roomId: chatRoom.id.toString(),
            senderId: sender.id.toString(), // Kirim senderId
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user: $error')),
      );
    }
  }

  void navigateToListChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserListChat()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Path ke gambar default
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Rooms'),
      ),
      body: FutureBuilder<List<ChatRoom>>(
        future: futureChatRooms,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text(
                    'Belum ada chat room.')); // Pesan ketika tidak ada chat room
          }

          List<ChatRoom> chatRooms = snapshot.data!;

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              // Tentukan ID pengguna yang akan diambil
              String targetUserId = chatRooms[index].receiverId == userId
                  ? chatRooms[index]
                      .senderId! // Ambil senderId jika receiverId sama dengan userId
                  : (chatRooms[index]
                      .receiverId!); // Ganti "default_id" dengan ID default yang sesuai

              return FutureBuilder<User>(
                future: user_service.UserService().fetchUser(
                    targetUserId), // Ambil data pengguna untuk setiap chat room
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'), // Tampilkan indikator loading
                    );
                  } else if (userSnapshot.hasError) {
                    return ListTile(
                      title: Text(
                          'Error: ${userSnapshot.error}'), // Tampilkan pesan kesalahan
                    );
                  } else if (!userSnapshot.hasData) {
                    return const ListTile(
                      title: Text(
                          'User  not found'), // Tangani kasus di mana pengguna tidak ditemukan
                    );
                  }

                  User user = userSnapshot.data!; // Ambil pengguna yang diambil

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      child: Text(
                        user.username[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(user.email ??
                        "Unknown User"), // Tampilkan nama pengguna
                    onTap: () => navigateToChatScreen(chatRooms[
                        index]), // Navigasi ke layar chat saat diketuk
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToListChat,
        child: Icon(Icons.add, color: Color(0xFF0E197E)),
        tooltip: 'Tambah Chat',
      ),
    );
  }
}
