import '../../core/config/app_config.dart';

/// Model data pengguna Rehat Coffeehouse.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.birthdate,
    this.tier = 'Reguler',
    this.role = 'customer',
    this.points = 0,
    this.stamps = 0,
    this.isProfileComplete = false,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;

  /// Peran akun: 'customer' atau 'admin'.
  final String role;

  /// Benar hanya bila akun berperan admin DAN build ini menyertakan fitur
  /// admin. Pada build "customer" ([AppConfig.isAdminBuild] == false) selalu
  /// false, sehingga akun admin pun tampil & berperilaku sebagai pelanggan.
  bool get isAdmin => AppConfig.isAdminBuild && role == 'admin';

  /// Tanggal lahir (format 'yyyy-MM-dd'), diisi saat profile setup.
  final String? birthdate;

  /// Tier keanggotaan (mis. Reguler, Silver, Gold).
  final String tier;

  /// Total poin loyalitas (backend: `loyalty_points`).
  final int points;

  /// Jumlah stamp pada stamp card (backend: `stamp_count`).
  final int stamps;

  /// Apakah profil sudah dilengkapi (untuk alur onboarding).
  final bool isProfileComplete;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['full_name'] ?? '').toString();
    // Backend tidak selalu mengirim is_profile_complete (mis. GET /users/me),
    // jadi turunkan dari keberadaan nama bila tidak ada.
    final explicitComplete = json['is_profile_complete'] ?? json['isProfileComplete'];
    return UserModel(
      id: (json['id'] ?? '').toString(),
      name: name,
      phone: (json['phone'] ?? json['phone_number'] ?? '').toString(),
      email: json['email'] as String?,
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl']) as String?,
      birthdate: json['birthdate'] as String?,
      tier: (json['tier'] ?? 'Reguler').toString(),
      role: (json['role'] ?? 'customer').toString(),
      points: _asInt(json['loyalty_points'] ?? json['points']),
      stamps: _asInt(json['stamp_count'] ?? json['stamps']),
      isProfileComplete:
          explicitComplete == true ? true : (explicitComplete == null ? name.isNotEmpty : false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'avatar_url': avatarUrl,
        'birthdate': birthdate,
        'tier': tier,
        'role': role,
        'loyalty_points': points,
        'stamp_count': stamps,
        'is_profile_complete': isProfileComplete,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? birthdate,
    String? tier,
    int? points,
    int? stamps,
    bool? isProfileComplete,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      birthdate: birthdate ?? this.birthdate,
      tier: tier ?? this.tier,
      role: role,
      points: points ?? this.points,
      stamps: stamps ?? this.stamps,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
