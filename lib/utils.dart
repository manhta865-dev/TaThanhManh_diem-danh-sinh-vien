import 'package:flutter/material.dart';

const kPrimary = Color(0xFF00897B);
const kPrimaryDark = Color(0xFF00695C);

dynamic pick(Map? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    if (m[k] != null) return m[k];
  }
  return null;
}

String fmtDate(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  DateTime? d = DateTime.tryParse(s);
  if (d == null) return s.replaceFirst('T', ' ');
  // Server lưu UTC (không có hậu tố Z) -> coi là UTC rồi đổi sang giờ máy
  if (!s.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    d = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  }
  d = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String summarize(Map m, {List<String> skip = const ['id']}) {
  final parts = <String>[];
  for (final e in m.entries) {
    final v = e.value;
    if (skip.contains(e.key) || v == null || v is Map || v is List) continue;
    final s = v.toString();
    parts.add('${e.key}: ${RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(s) ? fmtDate(s) : s}');
  }
  return parts.join('  •  ');
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
    ));
}

/// Tiêu đề mục
class SectionTitle extends StatelessWidget {
  final String text;
  final String? sub;
  const SectionTitle(this.text, {super.key, this.sub});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      if (sub != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(sub!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
    ]),
  );
}

/// Banner chào có nền gradient
class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const GradientHeader({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [kPrimary, Color(0xFF26A69A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: Row(children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white24,
        child: Icon(icon, color: Colors.white, size: 30),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ]),
      ),
    ]),
  );
}

/// Thẻ thống kê
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          ),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.15)),
        ]),
      ],
    ),
  );
}