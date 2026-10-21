import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'admin/admin_main_screen.dart';
import 'auth/login_screen.dart';
import 'student/student_main_screen.dart';

/// Phân quyền: admin -> trang quản trị, còn lại -> trang sinh viên.
Widget homeFor(UserModel me) =>
    me.isAdmin ? AdminMainScreen(user: me) : StudentMainScreen(user: me);

Future<void> doLogout(BuildContext context) async {
  await ApiService.logout();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
  );
}