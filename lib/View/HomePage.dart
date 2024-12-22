import 'package:flutter/material.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';

class Homepage extends StatefulWidget {
  final Function(int) onMenuSelected;

  const Homepage({super.key, required this.onMenuSelected});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    notificationService.init();
    notificationService.configureFCM();
    notificationService.getDeviceToken().then((value) {
      print('device token');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to the Admin Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Statistics Overview:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard('Total Reports', '150', Icons.report),
                  _buildStatCard('Active Users', '300', Icons.group),
                  _buildStatCard(
                      'New Reports This Month', '20', Icons.new_releases),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Manage Reports:', Colors.orange),
              _buildActionCard('View All Reports', Icons.list, () {
                widget.onMenuSelected(1);
              }),
              const SizedBox(height: 20),
              _buildSectionTitle('User  Management:', Colors.green),
              _buildActionCard('Manage Users', Icons.person, () {
                // Tautkan ke halaman manajemen pengguna
                widget.onMenuSelected(4);
              }),
              const SizedBox(height: 20),
              _buildSectionTitle('Site Settings:', Colors.red),
              _buildActionCard('Site Configuration', Icons.settings, () {
                // Tautkan ke halaman pengaturan
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueAccent),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 30, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.blueAccent),
            ],
          ),
        ),
      ),
    );
  }
}
