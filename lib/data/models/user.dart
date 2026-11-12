import '../../core/server_time.dart';

class User {
  const User({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.position = '',
    this.nip = '',
    this.officeLocationId,
    this.officeName = '',
    this.tenantId,
    this.tenantName = '',
    this.tenantCode = '',
    this.isSuperAdmin = false,
    this.faceEnrolled = false,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String role;
  final String position;

  /// Employee number shown on the profile and approval screens.
  final String nip;
  final int? officeLocationId;
  final String officeName;
  final int? tenantId;
  final String tenantName;
  final String tenantCode;
  final bool isSuperAdmin;
  final bool faceEnrolled;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';

  bool get isSupervisor => role == 'supervisor';

  bool get isManager => isAdmin || isSupervisor;

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? passwordHash,
    String? role,
    String? position,
    String? nip,
    int? officeLocationId,
    String? officeName,
    int? tenantId,
    String? tenantName,
    String? tenantCode,
    bool? isSuperAdmin,
    bool? faceEnrolled,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      position: position ?? this.position,
      nip: nip ?? this.nip,
      officeLocationId: officeLocationId ?? this.officeLocationId,
      officeName: officeName ?? this.officeName,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      tenantCode: tenantCode ?? this.tenantCode,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      faceEnrolled: faceEnrolled ?? this.faceEnrolled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email.toLowerCase(),
      'password_hash': passwordHash,
      'role': role,
      'position': position,
      'nip': nip,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: (map['id'] as num?)?.toInt(),
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      passwordHash: (map['password_hash'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'employee',
      position: (map['position'] as String?) ?? '',
      nip: (map['nip'] as String?) ?? '',
      officeLocationId: (map['office_location_id'] as num?)?.toInt(),
      officeName: (map['office_location'] as String?) ?? '',
      tenantId: (map['tenant_id'] as num?)?.toInt(),
      tenantName: (map['tenant_name'] as String?) ?? '',
      tenantCode: (map['tenant_code'] as String?) ?? '',
      isSuperAdmin: map['is_super_admin'] == true,
      faceEnrolled: map['face_enrolled'] == true,
      createdAt: parseServerDate(map['created_at']) ?? DateTime.now(),
    );
  }
}
