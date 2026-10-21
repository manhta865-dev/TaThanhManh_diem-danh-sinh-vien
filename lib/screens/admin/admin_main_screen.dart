import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/attendance_session_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils.dart';
import '../../widgets/crud_screen.dart';
import '../../widgets/list_screen.dart';
import '../home_router.dart';
import 'class_students_screen.dart';

String _nested(Map<String, dynamic> m, String key, List<String> inner) {
  final v = m[key];
  if (v is Map) return '${pick(v, inner) ?? ''}';
  return '';
}

/// Đặt vị trí điểm danh của buổi = vị trí hiện tại của admin.
Future<String?> _setHere(Map<String, dynamic> m) async {
  if (!await Geolocator.isLocationServiceEnabled()) return 'Vui lòng bật GPS';
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    return 'Chưa được cấp quyền vị trí';
  }
  final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  final body = ApiService.cleanBody(m);
  body['viTriViDo'] = pos.latitude;
  body['viTriKinhDo'] = pos.longitude;
  final r = m['banKinhChoPhepMet'];
  body['banKinhChoPhepMet'] = (r is num && r > 0) ? r : 200;
  return ApiService.update('/api/BuoiDiemDanh', m['id'], body);
}

// ===== Cấu hình các màn hình CRUD (đặt NGOÀI class) =====
Widget _buoiScreen({bool embedded = false}) => CrudScreen(
  title: 'Buổi điểm danh',
  endpoint: '/api/BuoiDiemDanh',
  showAppBar: !embedded,
  fields: const [
    FieldDef('lopHocPhanId', 'Lớp học phần',
        kind: FieldKind.select, optionsEndpoint: '/api/LopHocPhan', labelKeys: ['maLopHocPhan']),
    FieldDef('soThuTuBuoi', 'Buổi số', kind: FieldKind.number),
    FieldDef('ngayDiemDanh', 'Ngày điểm danh', kind: FieldKind.date),
    FieldDef('gioBatDau', 'Giờ bắt đầu', kind: FieldKind.time),
    FieldDef('gioKetThuc', 'Giờ kết thúc', kind: FieldKind.time),
    FieldDef('banKinhChoPhepMet', 'Bán kính cho phép (m)', kind: FieldKind.number),
    FieldDef('ghiChu', 'Ghi chú'),
  ],
  titleOf: (m) => 'Buổi ${m['soThuTuBuoi'] ?? m['id']} • ${_nested(m, 'lopHocPhan', ['maLopHocPhan'])}',
  subtitleOf: (m) {
    final d = '${m['ngayDiemDanh'] ?? ''}';
    final hasPos = m['viTriViDo'] is num && m['viTriViDo'] != 0;
    return 'Ngày: ${d.length >= 10 ? d.substring(0, 10) : d}\n'
        'Giờ: ${m['gioBatDau'] ?? ''} - ${m['gioKetThuc'] ?? ''}\n'
        'Trạng thái: ${m['trangThai'] ?? ''}\n'
        'Vị trí lớp: ${hasPos ? 'đã đặt (bán kính ${m['banKinhChoPhepMet']} m)' : 'CHƯA ĐẶT'}';
  },
  actions: (ctx, m, reload) {
    final open = AttendanceSession.isOpen(m['trangThai']);
    return [
      TextButton.icon(
        icon: Icon(open ? Icons.lock : Icons.lock_open),
        label: Text(open ? 'Đóng buổi' : 'Mở buổi'),
        onPressed: () async {
          final err = await ApiService.toggleDongMo(m['id']);
          if (!ctx.mounted) return;
          if (err != null) {
            toast(ctx, err, error: true);
          } else {
            toast(ctx, open ? 'Đã đóng buổi' : 'Đã mở buổi');
            await reload();
          }
        },
      ),
      TextButton.icon(
        icon: const Icon(Icons.my_location),
        label: const Text('Đặt vị trí lớp'),
        onPressed: () async {
          final err = await _setHere(m);
          if (!ctx.mounted) return;
          if (err != null) {
            toast(ctx, err, error: true);
          } else {
            toast(ctx, 'Đã đặt vị trí lớp = vị trí hiện tại');
            await reload();
          }
        },
      ),
      TextButton.icon(
        icon: const Icon(Icons.fact_check),
        label: const Text('Xem điểm danh'),
        onPressed: () => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => ListScreen(
              title: 'Điểm danh • Buổi ${m['soThuTuBuoi'] ?? m['id']}',
              path: '/api/DiemDanh/by-buoi/${m['id']}',
              icon: Icons.how_to_reg,
              titleOf: (d) {
                final n = _nested(d, 'sinhVien', ['hoTen']);
                return n.isEmpty ? 'Sinh viên #${d['sinhVienId']}' : n;
              },
              subtitleOf: (d) =>
              '${fmtDate(d['thoiGianDiemDanh'])} • ${d['phuongThuc'] ?? ''}\n'
                  '${d['khoangCachMet'] is num ? '${(d['khoangCachMet'] as num).toStringAsFixed(0)} m' : ''} • '
                  '${d['hopLe'] == false ? 'KHÔNG HỢP LỆ: ${d['lyDoKhongHopLe'] ?? ''}' : 'Hợp lệ'}',
            ),
          ),
        ),
      ),
    ];
  },
);

Widget _sinhVienScreen() => CrudScreen(
  title: 'Sinh viên',
  endpoint: '/api/SinhVien',
  fields: const [
    FieldDef('maSV', 'Mã sinh viên'),
    FieldDef('hoTen', 'Họ tên'),
    FieldDef('email', 'Email'),
    FieldDef('soDienThoai', 'Số điện thoại'),
    FieldDef('lop', 'Lớp'),
    FieldDef('khoa', 'Khoa'),
  ],
  titleOf: (m) => '${m['maSV'] ?? ''} - ${m['hoTen'] ?? ''}',
  subtitleOf: (m) => '${m['email'] ?? ''}\nLớp: ${m['lop'] ?? ''} • Khoa: ${m['khoa'] ?? ''}\nSĐT: ${m['soDienThoai'] ?? ''}',
);

Widget _monHocScreen() => CrudScreen(
  title: 'Môn học',
  endpoint: '/api/MonHoc',
  fields: const [
    FieldDef('maMon', 'Mã môn'),
    FieldDef('tenMon', 'Tên môn'),
    FieldDef('soTinChi', 'Số tín chỉ', kind: FieldKind.number),
    FieldDef('moTa', 'Mô tả'),
  ],
  titleOf: (m) => '${m['maMon'] ?? ''} - ${m['tenMon'] ?? ''}',
  subtitleOf: (m) => 'Số tín chỉ: ${m['soTinChi'] ?? ''}\n${m['moTa'] ?? ''}',
);

Widget _lopHocPhanScreen() => CrudScreen(
  title: 'Lớp học phần',
  endpoint: '/api/LopHocPhan',
  fields: const [
    FieldDef('maLopHocPhan', 'Mã lớp học phần (VD: 24DTH02_LTDD)'),
    FieldDef('monHocId', 'Môn học',
        kind: FieldKind.select, optionsEndpoint: '/api/MonHoc', labelKeys: ['tenMon']),
    FieldDef('giangVien', 'Giảng viên'),
    FieldDef('phongHoc', 'Phòng học'),
    FieldDef('hocKy', 'Học kỳ (VD: HK1)'),
    FieldDef('namHoc', 'Năm học (VD: 2026-2027)'),
    FieldDef('soBuoi', 'Số buổi', kind: FieldKind.number),
  ],
  titleOf: (m) => '${m['maLopHocPhan'] ?? 'Lớp #${m['id']}'}',
  subtitleOf: (m) => 'Môn: ${_nested(m, 'monHoc', ['tenMon'])}\n'
      'GV: ${m['giangVien'] ?? ''}\nPhòng: ${m['phongHoc'] ?? ''} • ${m['hocKy'] ?? ''} • ${m['namHoc'] ?? ''} • ${m['soBuoi'] ?? ''} buổi',
  actions: (ctx, m, reload) => [
    TextButton.icon(
      icon: const Icon(Icons.groups),
      label: const Text('Sinh viên của lớp'),
      onPressed: () => Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => ClassStudentsScreen(
            lopId: int.tryParse('${m['id']}') ?? 0,
            lopName: '${m['maLopHocPhan'] ?? m['id']}',
          ),
        ),
      ),
    ),
  ],
);

Widget _donScreen() => CrudScreen(
  title: 'Đơn nghỉ phép',
  endpoint: '/api/DonNghiPhep',
  fields: const [],
  allowAdd: false,
  allowEdit: false,
  titleOf: (m) => 'Đơn #${m['id']} • ${_nested(m, 'sinhVien', ['hoTen'])}',
  subtitleOf: (m) => 'Lớp: ${_nested(m, 'lopHocPhan', ['maLopHocPhan'])}\n'
      'Ngày nghỉ: ${fmtDate(m['ngayNghi']).split(' ').first}\nLý do: ${m['lyDo'] ?? ''}\n'
      'Trạng thái: ${m['trangThai'] ?? ''}'
      '${(m['phanHoiGiaoVien'] ?? '').toString().isEmpty ? '' : '\nPhản hồi: ${m['phanHoiGiaoVien']}'}',
  actions: (ctx, m, reload) {
    Future<void> duyet(bool ok) async {
      final err = await ApiService.duyetDon(m['id'], {
        'trangThai': ok ? 'DaDuyet' : 'TuChoi',
        'phanHoiGiaoVien': ok ? 'Đã duyệt' : 'Từ chối',
      });
      if (!ctx.mounted) return;
      if (err != null) {
        toast(ctx, err, error: true);
      } else {
        toast(ctx, ok ? 'Đã duyệt đơn' : 'Đã từ chối đơn');
        await reload();
      }
    }

    return [
      FilledButton.icon(
          onPressed: () => duyet(true), icon: const Icon(Icons.check), label: const Text('Duyệt')),
      OutlinedButton.icon(
          onPressed: () => duyet(false), icon: const Icon(Icons.close), label: const Text('Từ chối')),
    ];
  },
);

// ===== Màn hình chính =====
class AdminMainScreen extends StatefulWidget {
  final UserModel user;
  const AdminMainScreen({super.key, required this.user});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final titles = ['Tổng quan', 'Buổi điểm danh', 'Quản lý'];
    final tabs = <Widget>[
      _StatsTab(user: widget.user),
      _buoiScreen(embedded: true),
      const _ManageTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Đăng xuất', onPressed: () => doLogout(context)),
        ],
      ),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: 'Buổi điểm danh'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Quản lý'),
        ],
      ),
    );
  }
}

class _ManageTab extends StatelessWidget {
  const _ManageTab();

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Color, Widget Function())>[
      ('Sinh viên', 'Thêm, sửa, xóa hồ sơ', Icons.people_alt, const Color(0xFF1E88E5), _sinhVienScreen),
      ('Môn học', 'Danh sách môn học', Icons.menu_book, const Color(0xFF8E24AA), _monHocScreen),
      ('Lớp học phần', 'Lớp và sinh viên của lớp', Icons.class_, const Color(0xFFF4511E), _lopHocPhanScreen),
      ('Đơn nghỉ phép', 'Duyệt hoặc từ chối đơn', Icons.mail, const Color(0xFF00897B), _donScreen),
    ];
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.95,
      children: [
        for (final it in items)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.$5())),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: it.$4.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(it.$3, color: it.$4, size: 28),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(it.$2, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ]),
              ]),
            ),
          ),
      ],
    );
  }
}

// ===== Tổng quan + Cảnh báo cấm thi =====
class _StatsTab extends StatefulWidget {
  final UserModel user;
  const _StatsTab({required this.user});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _lops = [];
  List<Map<String, dynamic>> _warn = [];
  int? _lopId;
  bool _loading = true;
  String? _error;

  static const _meta = <String, (String, IconData, Color)>{
    'tongSoSinhVien': ('Sinh viên', Icons.people_alt, Color(0xFF1E88E5)),
    'tongSoMonHoc': ('Môn học', Icons.menu_book, Color(0xFF8E24AA)),
    'tongSoLopHocPhan': ('Lớp học phần', Icons.class_, Color(0xFFF4511E)),
    'tongSoBuoiDiemDanhHomNay': ('Buổi hôm nay', Icons.event, Color(0xFF00897B)),
    'tongSoLuotDiemDanhHomNay': ('Lượt điểm danh', Icons.how_to_reg, Color(0xFF43A047)),
    'soSinhVienNguyCoCamThiToanTruong': ('SV nguy cơ cấm thi', Icons.warning_amber_rounded, Color(0xFFE53935)),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await ApiService.getJson('/api/ThongKe/tong-quan');
    final l = await ApiService.getList('/api/LopHocPhan');
    if (!mounted) return;
    setState(() {
      final d = s.data;
      _stats = d is Map ? Map<String, dynamic>.from(d['data'] is Map ? d['data'] : d) : {};
      _lops = l.items;
      _error = s.error;
      _loading = false;
    });
  }

  Future<void> _loadWarn(int id) async {
    setState(() => _lopId = id);
    final r = await ApiService.getList('/api/ThongKe/canh-bao-cam-thi/$id');
    if (!mounted) return;
    if (r.error != null) toast(context, r.error!, error: true);
    setState(() => _warn = r.items);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final cards = <Widget>[];
    _stats.forEach((k, v) {
      if (v is Map || v is List) return;
      final m = _meta[k] ?? (k, Icons.bar_chart, kPrimary);
      cards.add(StatCard(value: '$v', label: m.$1, icon: m.$2, color: m.$3));
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GradientHeader(
            title: 'Xin chào, ${widget.user.hoTen ?? widget.user.username}',
            subtitle: 'Quản trị viên • Hệ thống điểm danh',
            icon: Icons.admin_panel_settings,
          ),
          const SectionTitle('Thống kê hệ thống'),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: cards,
          ),
          const SectionTitle('Cảnh báo cấm thi', sub: 'Sinh viên vắng quá số buổi quy định theo lớp học phần'),
          DropdownButtonFormField<int>(
            value: _lopId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Chọn lớp học phần',
              prefixIcon: Icon(Icons.class_outlined),
            ),
            items: [
              for (final m in _lops)
                DropdownMenuItem<int>(
                  value: int.tryParse('${m['id']}'),
                  child: Text('${m['maLopHocPhan'] ?? 'Lớp #${m['id']}'}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) _loadWarn(v);
            },
          ),
          const SizedBox(height: 10),
          if (_lopId != null && _warn.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(Icons.verified, color: Colors.green.shade600),
                const SizedBox(width: 12),
                const Expanded(child: Text('Không có sinh viên nào bị cảnh báo')),
              ]),
            ),
          for (final w in _warn)
            Card(
              color: const Color(0xFFFFEBEE),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red),
                ),
                title: Text('${pick(w, ['hoTen', 'tenSinhVien', 'maSV', 'maSv']) ?? 'Sinh viên'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(summarize(w)),
              ),
            ),
        ],
      ),
    );
  }
}