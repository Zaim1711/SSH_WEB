import 'package:flutter/material.dart';
import 'package:ssh_web/Model/Pengaduan.dart';
import 'package:ssh_web/View/AdminPage/ReviewPage.dart';

class PengaduanPage extends StatefulWidget {
  @override
  _PengaduanPageState createState() => _PengaduanPageState();
}

class _PengaduanPageState extends State<PengaduanPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Pengaduan>>
      _pengaduanList; // Variabel untuk menampung data pengaduan

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pengaduanList = fetchPengaduan(); // Inisialisasi data pengaduan
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Color(0xFF0D187E), // Ubah warna AppBar agar lebih menarik
        title: const Text('Dashboard Pengaduan',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white, // Mengubah warna indikator tab
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(
              icon: Icon(
                Icons.assignment_turned_in,
              ),
              text: 'Validation',
            ),
            Tab(
                icon: Icon(
                  Icons.check_circle,
                ),
                text: 'Approved'),
            Tab(
                icon: Icon(
                  Icons.cancel,
                ),
                text: 'Rejected'),
          ],
        ),
      ),
      body: FutureBuilder<List<Pengaduan>>(
        future: _pengaduanList, // Pastikan fungsi fetchPengaduan() sudah benar
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada data pengaduan.'));
          } else {
            final pengaduanList = snapshot.data!;

            // Pisahkan data berdasarkan status menggunakan enum
            final validationData = pengaduanList
                .where((pengaduan) =>
                    pengaduan.status.toString().split('.').last == 'Validation')
                .toList();

            final approvedData = pengaduanList
                .where((pengaduan) =>
                    pengaduan.status.toString().split('.').last == 'Approved')
                .toList();

            final rejectedData = pengaduanList
                .where((pengaduan) =>
                    pengaduan.status.toString().split('.').last == 'Rejected')
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                // Tabel untuk Validation
                _buildDataTable(validationData),
                // Tabel untuk Approved
                _buildDataTable(approvedData),
                // Tabel untuk Rejected
                _buildDataTable(rejectedData),
              ],
            );
          }
        },
      ),
    );
  }

  // Fungsi untuk membuat tabel dengan tombol Review
  Widget _buildDataTable(List<Pengaduan> pengaduanData) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DataTable(
              columns: const [
                DataColumn(
                    label: Text('ID',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Nama',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Jenis Kekerasan',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Status',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Review',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: pengaduanData.map((pengaduan) {
                return DataRow(cells: [
                  DataCell(Text(pengaduan.id.toString())),
                  DataCell(Text(pengaduan.name)),
                  DataCell(Text(pengaduan.jenisKekerasan)),
                  DataCell(Text(pengaduan.status
                      .toString()
                      .split('.')
                      .last)), // Mengambil nama enum status

                  DataCell(
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D187E), // Warna tombol
                        foregroundColor: Colors.white, // Warna teks tombol
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              12), // Rounded corner yang lebih besar
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12), // Padding lebih besar
                        elevation: 5, // Memberikan bayangan pada tombol
                        shadowColor: Colors.tealAccent
                            .withOpacity(0.5), // Warna bayangan tombol
                        side: const BorderSide(
                          color: Color(
                              0xFF0D187E), // Garis border yang lebih halus
                          width: 1.5, // Lebar border
                        ),
                      ),
                      onPressed: () {
                        _onReviewButtonPressed(
                            pengaduan); // Aksi saat tombol Review ditekan
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review,
                              size: 18), // Ikon untuk Review
                          SizedBox(width: 8), // Jarak antara ikon dan teks
                          Text('Review'),
                        ],
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _onReviewButtonPressed(Pengaduan pengaduan) async {
    print('Tombol Review ditekan untuk Pengaduan ID: ${pengaduan.id}');

    try {
      // Memanggil fungsi fetchPengaduanWithUser dengan mengirimkan pengaduan.id
      Pengaduan? selectedPengaduan = await fetchPengaduanWithUser(pengaduan.id);

      if (selectedPengaduan != null) {
        print('Pengaduan ditemukan: ${selectedPengaduan.name}');

        // Tampilkan dialog sebagai pop-up
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width *
                      0.5, // Maksimal lebar 80% dari lebar layar
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Pengaduan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Menampilkan konten ReviewPage yang membutuhkan objek Pengaduan
                      ReviewPage(pengaduan: selectedPengaduan),

                      const SizedBox(height: 20),

                      // Tombol untuk menutup dialog
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Menutup dialog
                          },
                          child: const Text('Tutup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ).then((_) {
          // Menjalankan setState setelah dialog ditutup
          setState(() {
            _pengaduanList =
                fetchPengaduan(); // Memanggil ulang fetchPengaduan untuk memuat data terbaru
          });
        });
      } else {
        print('Pengaduan tidak ditemukan!');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
