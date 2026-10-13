class User {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String role;
  final String? region;
  final String? subCity;
  final String? woreda;
  final String? photoUrl;
  final String? preferredLanguage;
  final bool accessibilityMode;
  final bool isVerified;
  final bool isActive;

  User({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.role = 'citizen',
    this.region,
    this.subCity,
    this.woreda,
    this.photoUrl,
    this.preferredLanguage = 'en',
    this.accessibilityMode = false,
    this.isVerified = false,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    role: json['role'] as String? ?? 'citizen',
    region: json['region'] as String?,
    subCity: json['sub_city'] as String?,
    woreda: json['woreda'] as String?,
    photoUrl: json['photo_url'] as String?,
    preferredLanguage: json['preferred_language'] as String? ?? 'en',
    accessibilityMode: json['accessibility_mode'] as bool? ?? false,
    isVerified: json['is_verified'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'phone': phone,
    'email': email,
    'role': role,
    'region': region,
    'sub_city': subCity,
    'woreda': woreda,
    'photo_url': photoUrl,
    'preferred_language': preferredLanguage,
    'accessibility_mode': accessibilityMode,
    'is_verified': isVerified,
    'is_active': isActive,
  };
}
