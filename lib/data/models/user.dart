class AppUser {
  final int id;
  final String username;
  final String role; // 'admin' | 'cashier'
  final String? displayName;
  final bool isActive;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.displayName,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int,
        username: m['username'] as String,
        role: m['role'] as String,
        displayName: m['display_name'] as String?,
        isActive: (m['is_active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
