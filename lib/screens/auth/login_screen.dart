import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils.dart';
import '../home_router.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _hide = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<String?> _askOtp(String user, String? otp, String? info) {
    final c = TextEditingController(text: otp ?? '');
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác thực OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tài khoản: $user'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: otp != null
                  ? Column(children: [
                const Text('Mã OTP của bạn'),
                Text(otp,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: kPrimary)),
              ])
                  : Text(info ?? 'Server đã gửi OTP.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nhập mã OTP (6 số)', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final v = c.text.trim();
              if (v.length == 6) Navigator.pop(ctx, v);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.isEmpty || p.isEmpty) {
      toast(context, 'Vui lòng nhập tên đăng nhập và mật khẩu', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final r = await ApiService.requestOtp(u, p);
      if (!mounted) return;
      if (r.error != null) {
        toast(context, r.error!, error: true);
        return;
      }
      final otp = await _askOtp(u, r.otp, r.info);
      if (otp == null || !mounted) return;

      final lerr = await ApiService.login(u, p, otp);
      if (!mounted) return;
      if (lerr != null) {
        toast(context, lerr, error: true);
        return;
      }
      final me = await ApiService.getMe();
      if (!mounted) return;
      if (me == null) {
        toast(context, 'Không lấy được thông tin tài khoản', error: true);
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => homeFor(me)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goRegister() async {
    final r = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (r != null) _user.text = r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.school, size: 84, color: kPrimary),
                const SizedBox(height: 12),
                const Text('HỆ THỐNG ĐIỂM DANH',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary)),
                const SizedBox(height: 4),
                const Text('Đăng nhập bảo mật 2 lớp (OTP)', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 28),
                TextField(
                  controller: _user,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pass,
                  enabled: !_loading,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  onSubmitted: (_) => _loading ? null : _submit(),
                ),
                const SizedBox(height: 24),
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
                        : const Text('ĐĂNG NHẬP (GỬI OTP)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _goRegister,
                  child: const Text('Chưa có tài khoản? Đăng ký sinh viên'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}