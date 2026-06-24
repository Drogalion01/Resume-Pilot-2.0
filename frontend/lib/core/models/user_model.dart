// lib/core/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? initials;
  final bool emailVerified;
  final String plan; // "free" | "pro"
  final bool isActive;
  final bool onboardingCompleted;

  const UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.initials,
    required this.emailVerified,
    required this.plan,
    required this.isActive,
    required this.onboardingCompleted,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        initials: json['initials'] as String?,
        emailVerified: (json['is_email_verified'] as bool?) ?? (json['email_verified'] as bool?) ?? false,
        plan: (json['subscription_tier'] as String?) ?? (json['plan'] as String?) ?? 'free',
        isActive: json['is_active'] as bool? ?? true,
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'initials': initials,
        'email_verified': emailVerified,
        'plan': plan,
        'is_active': isActive,
        'onboarding_completed': onboardingCompleted,
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? initials,
    bool? emailVerified,
    String? plan,
    bool? isActive,
    bool? onboardingCompleted,
  }) =>
      UserModel(
        id: id ?? this.id,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        initials: initials ?? this.initials,
        emailVerified: emailVerified ?? this.emailVerified,
        plan: plan ?? this.plan,
        isActive: isActive ?? this.isActive,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );

  bool get isPro => plan == 'pro';
  String get displayName => fullName ?? email.split('@').first;
  String get avatarInitials => initials ?? email.substring(0, 2).toUpperCase();
}
