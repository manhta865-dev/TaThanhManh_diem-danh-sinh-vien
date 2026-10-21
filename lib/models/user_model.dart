class UserModel {
  final String username;
  final String role;
  final String? maSv;
  final String? hoTen;
  final String? email;

  UserModel({required this.username, required this.role, this.maSv, this.hoTen, this.email});

  factory UserModel.fromJson(Map<String, dynamic> j) {
    dynamic role = j['role'] ??
        j['roles'] ??
        j['vaiTro'] ??
        j['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];
    if (role is List) role = role.join(',');
    return UserModel(
      username: (j['username'] ?? j['userName'] ?? j['unique_name'] ?? j['name'] ?? j['sub'] ?? '').toString(),
      role: (role ?? '').toString(),
      maSv: (j['maSv'] ?? j['maSV'] ?? j['masv'])?.toString(),
      hoTen: (j['hoTen'] ?? j['fullName'])?.toString(),
      email: (j['email'] ?? j['Email'])?.toString(),
    );
  }

  bool get isAdmin {
    final r = role.toLowerCase();
    return r.contains('admin') || r.contains('giang');
  }
}