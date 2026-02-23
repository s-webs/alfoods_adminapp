class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final double? personalDiscountPercent;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.personalDiscountPercent,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) ?? 'viewer',
      personalDiscountPercent: json['personal_discount_percent'] != null
          ? (json['personal_discount_percent'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'personal_discount_percent': personalDiscountPercent,
      };

  bool get isAdmin => role == 'admin';
}
