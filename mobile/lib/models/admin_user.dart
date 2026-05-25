class AdminUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String mobile;
  final String? role;

  AdminUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    this.role,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory AdminUser.fromMap(Map<String, dynamic> map, String id) {
    return AdminUser(
      uid: id,
      firstName: map['firstName'] ?? map['first_name'] ?? '',
      lastName: map['lastName'] ?? map['last_name'] ?? '',
      mobile: map['mobile'] ?? map['mobileNumber'] ?? '',
      role: map['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'mobile': mobile,
      if (role != null) 'role': role,
    };
  }
}
