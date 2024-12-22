import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/NotificationRequest.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final String baseUrl = 'http://localhost:8080/api/tokens';
  StreamSubscription? _messageSubscription;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Inisialisasi notifikasi
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onSelectNotification);

    // Membuat saluran notifikasi
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'your_channel_id', // ID saluran
      'Your Channel Name', // Nama saluran
      description: 'Your channel description',
      importance: Importance.high,
    );

    // Buat saluran (akan menimpa jika sudah ada)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id', // Pastikan ini cocok dengan ID saluran Anda
      'Your Channel Name', // Nama saluran
      channelDescription: 'Your channel description', // Deskripsi saluran
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher', // Gunakan ikon kecil Anda di sini
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now()
          .millisecondsSinceEpoch
          .remainder(100000), // ID unik untuk setiap notifikasi
      title, // Judul notifikasi
      body, // Isi notifikasi
      platformChannelSpecifics,
      payload: 'item x', // Anda dapat menyesuaikan payload ini sesuai kebutuhan
    );
  }

  // void showWebNotification(String title, String body) {
  //   // Memeriksa izin notifikasi
  //   if (html.Notification.permission == 'granted') {
  //     // Membuat objek notifikasi dengan judul dan isi
  //     html.Notification notification = html.Notification(title);
  //   } else if (html.Notification.permission != 'denied') {
  //     // Meminta izin notifikasi
  //     html.Notification.requestPermission().then((permission) {
  //       if (permission == 'granted') {
  //         // Membuat objek notifikasi dengan judul dan isi setelah izin diberikan
  //         html.Notification notification = html.Notification(title);
  //       }
  //     });
  //   }
  // }

  Future<void> onSelectNotification(NotificationResponse response) async {}

  Future<void> configureFCM() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Izin notifikasi diberikan');
    } else {
      print('Izin notifikasi ditolak');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Pesan diterima di foreground: ${message.notification?.title}');
      showNotification(message.notification?.title ?? 'Tanpa Judul',
          message.notification?.body ?? 'Tanpa Isi');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Pesan dibuka: ${message.notification?.title}');
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print("Menangani pesan latar belakang: ${message.messageId}");

    // Periksa apakah payload notifikasi ada
    if (message.notification != null) {
      // Tampilkan notifikasi saat aplikasi berada di latar belakang
      final service = NotificationService();
      await service.showNotification(
        message.notification!.title ?? 'Tanpa Judul',
        message.notification!.body ?? 'Tanpa Isi',
      );
    } else {
      // Tangani kasus di mana payload notifikasi null
      print('Payload notifikasi latar belakang adalah null');
    }

    // Jika ada data tambahan
    if (message.data.isNotEmpty) {
      String chatRoomId = message.data['roomId'] ?? '';
      String senderId = message.data['senderId'] ?? '';
      String messageContent = message.data['messageContent'] ?? '';

      // Tampilkan notifikasi dengan informasi tambahan
      final service = NotificationService();
      await service.showNotification(
          'Pesan Baru dari $senderId', // Judul notifikasi
          messageContent // Isi notifikasi
          );
    }
  }

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // void requestNotificationPermission() async {
  //   NotificationSettings settings = await messaging.requestPermission(
  //     alert: true,
  //     announcement: true,
  //     badge: true,
  //     carPlay: true,
  //     criticalAlert: true,
  //     provisional: true,
  //     sound: true,
  //   );

  //   if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  //     print('Pengguna memberikan izin');
  //   } else if (settings.authorizationStatus ==
  //       AuthorizationStatus.provisional) {
  //     print('Pengguna memberikan izin sementara');
  //   } else {
  //     AppSettings.openAppSettings();
  //     print('Pengguna menolak atau belum memberikan izin');
  //   }
  // }

  Future<void> getDeviceToken() async {
    try {
      // Mendapatkan token perangkat
      String? deviceToken = await messaging.getToken();
      print(deviceToken);
      if (deviceToken != null) {
        // Mendapatkan ID pengguna dari token akses
        await decodeTokenAndSendToServer(deviceToken);
      } else {
        print('Token perangkat tidak ditemukan');
      }
    } catch (e) {
      print('Error mendapatkan token perangkat: $e');
    }
  }

  Future<void> decodeTokenAndSendToServer(String deviceToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      // Mendekode token JWT
      Map<String, dynamic> payload = JwtDecoder.decode(accessToken);
      String userId = payload['sub'].split(',')[0];
      print(userId);

      // Mengirim token ke server
      await sendTokenToServer(deviceToken, userId);
    } else {
      print('Access token tidak ditemukan');
    }
  }

  Future<void> sendTokenToServer(String deviceToken, String userId) async {
    final url =
        'http://localhost:8080/api/tokens'; // Ganti dengan URL endpoint Anda

    // Ambil access token dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $accessToken', // Menambahkan JWT token ke header
        },
        body: json.encode({
          'token': deviceToken,
          'userId': userId, // Kirim userId ke server
        }),
      );

      if (response.statusCode == 200) {
        print('Token berhasil disimpan di server');
      } else {
        print('Gagal menyimpan token: ${response.body}');
      }
    } catch (e) {
      print('Error saat mengirim token ke server: $e');
    }
  }

  void isTokenRefresh() async {
    messaging.onTokenRefresh.listen((event) {
      print('Token diperbarui: $event');
    }); // Mendengarkan token refresh
  }

  Future<void> sendNotification(
      String userId, String title, String body) async {
    final url = Uri.parse('$baseUrl/send-notification');

    // Ambil access token dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    final notificationRequest =
        NotificationRequest(userId: userId, title: title, body: body);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $accessToken', // Ganti dengan token akses yang valid
        },
        body: json.encode(notificationRequest.toJson()),
      );

      if (response.statusCode == 200) {
        print('Notifikasi berhasil dikirim');
      } else {
        print('Gagal mengirim notifikasi: ${response.body}');
      }
    } catch (e) {
      print('Error saat mengirim notifikasi: $e');
    }
  }
}
