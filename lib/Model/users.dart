class Users {
  final int id;
  final String username;
  final String email;
  final Role role;

  Users(
      {required this.id,
      required this.username,
      required this.email,
      required this.role});

  factory Users.fromJson(Map<String, dynamic> json, List<Role> roles) {
    Role userRole = roles.firstWhere((role) => role.id == json['roleId']);
    return Users(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: userRole,
    );
  }
}

class Role {
  final int id;
  final String name;

  Role({required this.id, required this.name});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
    );
  }
}
