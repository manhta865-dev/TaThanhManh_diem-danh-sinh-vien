import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils.dart';

/// Nếu API từ chối vì role, hãy đổi chuỗi này cho đúng với backend (xem schema/seed).
const kStudentRole = 'Student';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _hoTen = TextEditingController();
  final _maSv = TextEditingController();
  final _lop = TextEditingController();
  final _khoa = TextEditingController();
  final _sdt = TextEditingController();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_hoTen, _maSv, _lop, _khoa, _sdt, _user, _email, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .join();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await ApiService.register({
      'username': _user.text.trim(),
      'email': _email.text.trim(),
      'password': _pass.text,
      'initials': _initials(_hoTen.text),
      'role': kStudentRole,
      'maSV': _maSv.text.trim(),
      'hoTen': _hoTen.text.trim(),
      'lop': _lop.text.trim(),
      'khoa': _khoa.text.trim(),
      'soDienThoai': _sdt.text.trim(),
    });
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      toast(context, err, error: true);
      return;
    }
    toast(context, 'Đăng ký thành công! Hãy đăng nhập.');
    Navigator.pop(context, _user.text.trim());
  }

  Widget _f(TextEditingController c, String label, IconData icon,
      {bool obscure = false,
        TextInputType? type,
        String? Function(String?)? validator,
        bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: validator ??
                (v) => (required && (v == null || v.trim().isEmpty)) ? 'Không được để trống' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản sinh viên')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            children: [
              _f(_hoTen, 'Họ và tên', Icons.badge_outlined),
              _f(_maSv, 'Mã số sinh viên', Icons.numbers),
              _f(_lop, 'Lớp', Icons.class_outlined),
              _f(_khoa, 'Khoa', Icons.account_balance_outlined),
              _f(_sdt, 'Số điện thoại', Icons.phone_outlined, type: TextInputType.phone),
              _f(_user, 'Tên đăng nhập', Icons.person_outline),
              _f(_email, 'Email (nhận OTP)', Icons.email_outlined,
                  type: TextInputType.emailAddress,
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
                      ? null
                      : 'Email không hợp lệ'),
              _f(_pass, 'Mật khẩu', Icons.lock_outline,
                  obscure: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null),
              _f(_pass2, 'Nhập lại mật khẩu', Icons.lock_reset,
                  obscure: true,
                  validator: (v) => v != _pass.text ? 'Mật khẩu không khớp' : null),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('ĐĂNG KÝ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}