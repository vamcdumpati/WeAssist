class HospitalVisit {
  final String id;
  final String patientId;
  final String patientName;
  final String hospitalName;
  final String hospitalArea;
  final double caretakerLat;
  final double caretakerLng;
  final String emergencyContact;
  final String patientMobile;
  final String status; // 'scheduled', 'transit', 'completed'
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  HospitalVisit({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.hospitalName,
    required this.hospitalArea,
    required this.caretakerLat,
    required this.caretakerLng,
    required this.emergencyContact,
    required this.patientMobile,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory HospitalVisit.fromMap(Map<String, dynamic> map, String id) {
    return HospitalVisit(
      id: id,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      hospitalName: map['hospitalName'] ?? '',
      hospitalArea: map['hospitalArea'] ?? '',
      caretakerLat: (map['caretakerLat'] as num?)?.toDouble() ?? 0.0,
      caretakerLng: (map['caretakerLng'] as num?)?.toDouble() ?? 0.0,
      emergencyContact: map['emergencyContact'] ?? '',
      patientMobile: map['patientMobile'] ?? '',
      status: map['status'] ?? 'scheduled',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      startedAt: map['startedAt'] != null ? DateTime.parse(map['startedAt']) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'hospitalName': hospitalName,
      'hospitalArea': hospitalArea,
      'caretakerLat': caretakerLat,
      'caretakerLng': caretakerLng,
      'emergencyContact': emergencyContact,
      'patientMobile': patientMobile,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
