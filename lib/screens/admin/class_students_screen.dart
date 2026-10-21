import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils.dart';

/// Quản lý sinh viên thuộc 1 lớp học phần (thêm / xóa).
class ClassStudentsScreen extends StatefulWidget {
  final int lopId;
  final String lopName;
  const ClassStudentsScreen({super.key, required this.lopId, required this.lopName});

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  List<Map<String, dynamic>> _enrolled = [];
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _svId(Map<String, dynamic> m) => int.tryParse('${m['sinhVienId'] ?? m['id']}');

  Map<String, dynamic>? _info(Map<String, dynamic> m) {
    if (m['sinhVien'] is Map) return Map<String, dynamic>.from(m['sinhVien']);
    final id = _svId(m);
    for (final s in _all) {
      if (int.tryParse('${s['id']}') == id) return s;
    }
    return m['maSV'] != null ? m : null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ApiService.getList('/api/SinhVien');
    final r = await ApiService.getList('/api/LopHocPhan/${widget.lopId}/sinh-viens');
    if (!mounted) return;
    setState(() {
      _all = all.items;
      _enrolled = r.items;
      _error = r.error;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final have = _enrolled.map(_svId).toSet();
    final candidates = _all.where((s) => !have.contains(int.tryParse('${s['id']}'))).toList();
    if (candidates.isEmpty) {
      toast(context, 'Không còn sinh viên nào để thêm', error: true);
      return;
    }
    final id = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn sinh viên'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            for (final s in candidates)
              ListTile(
                title: Text('${s['hoTen'] ?? ''}'),
                subtitle: Text('${s['maSV'] ?? ''}'),
                onTap: () => Navigator.pop(ctx, int.tryParse('${s['id']}')),
              ),
          ]),
        ),
      ),
    );
    if (id == null || !mounted) return;
    final err = await ApiService.themSinhVienVaoLop(widget.lopId, id);
    if (!mounted) return;
    if (err != null) {
      toast(context, err, error: true);
    } else {
      toast(context, 'Đã thêm sinh viên vào lớp');
      _load();
    }
  }

  Future<void> _remove(int svId) async {
    final err = await ApiService.xoaSinhVienKhoiLop(widget.lopId, svId);
    if (!mounted) return;
    if (err != null) {
      toast(context, err, error: true);
    } else {
      toast(context, 'Đã xóa khỏi lớp');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sinh viên • ${widget.lopName}')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.person_add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : RefreshIndicator(
        onRefresh: _load,
        child: _enrolled.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Lớp chưa có sinh viên'))])
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: _enrolled.length,
          itemBuilder: (_, i) {
            final m = _enrolled[i];
            final sv = _info(m);
            final id = _svId(m);
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.person, color: kPrimary)),
                title: Text('${sv?['hoTen'] ?? 'Sinh viên #$id'}'),
                subtitle: Text('${sv?['maSV'] ?? ''}  ${sv?['lop'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: id == null ? null : () => _remove(id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}