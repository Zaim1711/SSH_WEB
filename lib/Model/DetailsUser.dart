class DetailsUser {
  final int id;
  final int nik;
  final String alamat;
  final String nomorTelepon;
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
      id: json['id'] as int,
      nik: json['nik'] as int,
      alamat: json['alamat'] as String,
      nomorTelepon: json['nomor_telepon'].toString(),
      imageUrl: json['imageUrl'] as String?,
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nik': nik,
      'alamat': alamat,
      'nomor_telepon': nomorTelepon,
      'imageUrl': imageUrl,
      'userId': userId,
    };
  }
}
