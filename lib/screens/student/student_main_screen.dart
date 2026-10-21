import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/attendance_session_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils.dart';
import '../home_router.dart';
import 'student_leave_tab.dart';
import 'student_ocr_tab.dart';
import 'student_stats_tab.dart';
class StudentMainScreen extends StatefulWidget {
  final UserModel user;
  const StudentMainScreen({super.key, required this.user});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _index = 0;
  int? _svId;
  bool _loading = true;

  String get maSv => widget.user.maSv ?? widget.user.username;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final sv = await ApiService.ensureSinhVien(widget.user);
    if (!mounted) return;
    setState(() {
      _svId = int.tryParse('${sv?['id']}');
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Điểm danh', 'Thống kê', 'Lịch sử', 'Nghỉ phép', 'Dịch ảnh'];
    final tabs = <Widget>[
      _AttendanceTab(maSv: maSv),
      StatsTab(svId: _svId),
      _HistoryTab(svId: _svId),
      LeaveTab(svId: _svId),
      const OcrTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.hoTen ?? maSv} • ${titles[_index]}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Đăng xuất', onPressed: () => doLogout(context)),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fingerprint), label: 'Điểm danh'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Thống kê'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.mail_outline), label: 'Nghỉ phép'),
          NavigationDestination(icon: Icon(Icons.translate), label: 'Dịch ảnh'),
        ],
      ),
    );
  }
}

// ================= Tab điểm danh: vân tay + GPS =================
class _AttendanceTab extends StatefulWidget {
  final String maSv;
  const _AttendanceTab({required this.maSv});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  final _auth = LocalAuthentication();
  List<AttendanceSession> _sessions = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ApiService.getList('/api/BuoiDiemDanh');
    if (!mounted) return;
    final list = r.items.map(AttendanceSession.fromJson).toList()
      ..sort((a, b) {
        if (a.dangMo != b.dangMo) return a.dangMo ? -1 : 1;
        return b.ngay.compareTo(a.ngay);
      });
    setState(() {
      _sessions = list;
      _error = r.error;
      _loading = false;
    });
  }

  /// (e) Nhận diện vân tay
  Future<bool> _verifyFingerprint() async {
    try {
      if (!await _auth.isDeviceSupported()) {
        if (mounted) toast(context, 'Thiết bị không hỗ trợ sinh trắc học', error: true);
        return false;
      }
      return await _auth.authenticate(
        localizedReason: 'Quét vân tay để xác nhận điểm danh',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException catch (e) {
      if (mounted) {
        toast(context, 'Không dùng được vân tay (${e.code}). Hãy cài đặt vân tay trong Cài đặt máy.',
            error: true);
      }
      return false;
    }
  }

  /// (b) Lấy vị trí GPS
  Future<Position?> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) toast(context, 'Vui lòng bật GPS', error: true);
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      if (mounted) toast(context, 'Chưa được cấp quyền vị trí', error: true);
      return null;
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  /// (b) Chia sẻ vị trí: sao chép liên kết Google Maps
  Future<void> _shareLocation() async {
    setState(() => _busy = true);
    try {
      final p = await _getPosition();
      if (p == null) return;
      setState(() => _pos = p);
      await Clipboard.setData(ClipboardData(text: 'https://maps.google.com/?q=${p.latitude},${p.longitude}'));
      if (mounted) toast(context, 'Đã sao chép liên kết vị trí, hãy dán để chia sẻ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn(AttendanceSession s) async {
    setState(() => _busy = true);
    try {
      if (!await _verifyFingerprint()) {
        if (mounted) toast(context, 'Xác thực vân tay không thành công', error: true);
        return;
      }
      final p = await _getPosition();
      if (p == null) return;
      setState(() => _pos = p);
      final r = await ApiService.checkInRaw(
          buoiId: s.id, maSv: widget.maSv, lat: p.latitude, lng: p.longitude);
      if (!mounted) return;
      final ok = r['thanhCong'] == true;
      final km = r['khoangCachMet'];
      final dist = km is num ? ' (cách lớp ${km.toStringAsFixed(0)} m)' : '';
      toast(
        context,
        '${r['thongBao'] ?? (ok ? 'Điểm danh thành công' : 'Điểm danh thất bại')}$dist',
        error: !ok,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: const Color(0xFFE0F2F1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.my_location, color: kPrimary),
                  SizedBox(width: 8),
                  Text('Vị trí của bạn', style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Text(_pos == null
                    ? 'Chưa lấy vị trí'
                    : 'Vĩ độ: ${_pos!.latitude.toStringAsFixed(6)}\nKinh độ: ${_pos!.longitude.toStringAsFixed(6)}'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _shareLocation,
                  icon: const Icon(Icons.share_location),
                  label: const Text('Chia sẻ vị trí'),
                ),
              ]),
            ),
          ),
          const SectionTitle('Các buổi điểm danh', sub: 'Bấm "Điểm danh" → quét vân tay → gửi kèm vị trí GPS'),
          if (_loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (!_loading && _error == null && _sessions.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Chưa có buổi điểm danh nào'))),
          for (final s in _sessions)
            Card(
              child: ListTile(
                leading: Icon(s.dangMo ? Icons.lock_open : Icons.lock, color: s.dangMo ? kPrimary : Colors.grey),
                title: Text('${s.tenBuoi}${s.lop.isEmpty ? '' : ' • ${s.lop}'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${s.ngay}${s.gio.isEmpty ? '' : '  ${s.gio}'}\n'
                    '${s.dangMo ? 'Đang mở' : 'Chưa mở'} [${s.trangThai}]'),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: (s.dangMo && !_busy) ? () => _checkIn(s) : null,
                  child: const Text('Điểm danh'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= Tab lịch sử điểm danh =================
class _HistoryTab extends StatefulWidget {
  final int? svId;
  const _HistoryTab({required this.svId});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.svId == null) {
      setState(() {
        _loading = false;
        _error = 'Không tìm thấy hồ sơ sinh viên cho tài khoản này';
      });
      return;
    }
    setState(() => _loading = true);
    final r = await ApiService.getList('/api/DiemDanh/by-sinh-vien/${widget.svId}');
    if (!mounted) return;
    setState(() {
      _items = r.items;
      _error = r.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Chưa có lịch sử điểm danh'))])
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final m = _items[i];
          final b = m['buoiDiemDanh'] is Map ? m['buoiDiemDanh'] as Map : {};
          final valid = m['hopLe'] != false;
          final km = m['khoangCachMet'];
          return Card(
            child: ListTile(
              leading: Icon(valid ? Icons.check_circle : Icons.cancel, color: valid ? kPrimary : Colors.red),
              title: Text('Buổi ${b['soThuTuBuoi'] ?? m['buoiDiemDanhId'] ?? m['id']}'),
              subtitle: Text('${fmtDate(m['thoiGianDiemDanh'])}\n'
                  '${m['phuongThuc'] ?? ''}${km is num ? ' • ${km.toStringAsFixed(0)} m' : ''} • ${m['trangThai'] ?? ''}'
                  '${valid ? '' : '\n${m['lyDoKhongHopLe'] ?? 'Không hợp lệ'}'}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}