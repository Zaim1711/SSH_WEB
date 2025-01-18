class DetailsUser {
  final int id;
  final int nik;
  final String alamat;
  final int nomorTelepon;
  final String? imageUrl;
  final String userId;

  DetailsUser({
    required this.id,
    required this.nik,
    required this.alamat,
    required this.nomorTelepon,
    this.imageUrl,
    required this.userId,
  });

  factory DetailsUser.fromJson(Map<String, dynamic> json) {
    return DetailsUser(
      id: json['id'],
      nik: json['nik'],
      alamat: json['alamat'] ?? '',
      nomorTelepon: json['nomor_telepon'],
      imageUrl: json['imageUrl'],
      userId: json['userId'].toString(),
    );
  }
}
