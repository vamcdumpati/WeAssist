class Patient {
  final String id;
  final String name;
  final DateTime dob;
  final String gender;
  final double height; // in cm
  final double weight; // in kg
  final String photoUrl; // Could be local path, base64 or Firebase URL
  final String identityProofUrl; // Could be local path, base64 or Firebase URL
  final String mobile; // Patient's own mobile number
  final String emergencyContact;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.name,
    required this.dob,
    required this.gender,
    required this.height,
    required this.weight,
    required this.photoUrl,
    required this.identityProofUrl,
    required this.mobile,
    required this.emergencyContact,
    required this.createdAt,
  });

  int get age {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromMap(Map<String, dynamic> map, String id) {
    return Patient(
      id: id,
      name: map['name'] ?? '',
      dob: map['dob'] != null ? DateTime.parse(map['dob']) : DateTime.now(),
      gender: map['gender'] ?? '',
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      photoUrl: map['photoUrl'] ?? '',
      identityProofUrl: map['identityProofUrl'] ?? '',
      mobile: map['mobile'] ?? '',
      emergencyContact: map['emergencyContact'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dob': dob.toIso8601String(),
      'gender': gender,
      'height': height,
      'weight': weight,
      'photoUrl': photoUrl,
      'identityProofUrl': identityProofUrl,
      'mobile': mobile,
      'emergencyContact': emergencyContact,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
