import 'package:ssh_web/Model/Role.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String profileImage; // Attribute for profile image
  final List<Role> roles; // Change to List<Role>

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.profileImage,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Safely handle null values for roles
    var roleList =
        json['roles'] as List? ?? []; // Default to an empty list if null
    List<Role> roles = roleList.map((role) => Role.fromJson(role)).toList();

    return User(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'],
      profileImage: json['profile_image'] ?? '',
      roles: roles,
    );
  }
}
