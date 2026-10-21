class AttendanceSession {
  final int id;
  final String tenBuoi;
  final String lop;
  final String ngay;
  final String gio;
  final String trangThai;
  final bool dangMo;

  AttendanceSession({
    required this.id,
    required this.tenBuoi,
    required this.lop,
    required this.ngay,
    required this.gio,
    required this.trangThai,
    required this.dangMo,
  });

  /// Buổi được coi là đang mở khi trangThai thuộc các giá trị dưới đây.
  static bool isOpen(dynamic t) {
    final s = (t ?? '').toString().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    const open = ['mo', 'dangmo', 'đangmở', 'mở', 'open', 'opened', 'active', 'dangdiendra', 'dangdiemdanh'];
    return open.contains(s);
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> j) {
    final date = (j['ngayDiemDanh'] ?? '').toString();
    final lopMap = j['lopHocPhan'] is Map ? j['lopHocPhan'] as Map : {};
    final monMap = lopMap['monHoc'] is Map ? lopMap['monHoc'] as Map : {};
    final tenMon = monMap['tenMon'] ?? '';
    final maLop = lopMap['maLopHocPhan'] ?? '';
    final gio = [j['gioBatDau'], j['gioKetThuc']]
        .where((e) => e != null && e.toString().isNotEmpty)
        .map((e) => e.toString().length >= 5 ? e.toString().substring(0, 5) : e.toString())
        .join(' - ');
    return AttendanceSession(
      id: int.tryParse('${j['id']}') ?? 0,
      tenBuoi: 'Buổi ${j['soThuTuBuoi'] ?? j['id']}',
      lop: '$tenMon${tenMon != '' && maLop != '' ? ' • ' : ''}$maLop',
      ngay: date.length >= 10 ? date.substring(0, 10) : date,
      gio: gio,
      trangThai: '${j['trangThai'] ?? ''}',
      dangMo: isOpen(j['trangThai']),
    );
  }
}