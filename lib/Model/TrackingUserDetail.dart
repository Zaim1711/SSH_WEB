class TrackingUserDetail {
  final String username;
  final String email;
  final String address;
  final int phoneNumber; // Mengganti Long dengan int
  final int nik; // Mengganti Long dengan int

  TrackingUserDetail({
    required this.username,
    required this.email,
    required this.address,
    required this.phoneNumber,
    required this.nik,
  });
}
