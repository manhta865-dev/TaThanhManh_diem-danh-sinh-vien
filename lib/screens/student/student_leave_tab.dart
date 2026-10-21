import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils.dart';

class LeaveTab extends StatefulWidget {
  final int? svId;
  const LeaveTab({super.key, required this.svId});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
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
    final r = await ApiService.getList('/api/DonNghiPhep/by-sinh-vien/${widget.svId}');
    if (!mounted) return;
    setState(() {
      _items = r.items;
      _error = r.error;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final lops = await ApiService.getList('/api/LopHocPhan');
    if (!mounted) return;
    if (lops.items.isEmpty) {
      toast(context, lops.error ?? 'Chưa có lớp học phần nào để xin nghỉ', error: true);
      return;
    }
    int? lopId = int.tryParse('${lops.items.first['id']}');
    DateTime ngay = DateTime.now();
    final lyDo = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Gửi đơn nghỉ phép'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: lopId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lớp học phần'),
                items: [
                  for (final m in lops.items)
                    DropdownMenuItem<int>(
                      value: int.tryParse('${m['id']}'),
                      child: Text('${m['maLopHocPhan'] ?? 'Lớp #${m['id']}'}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setS(() => lopId = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('Ngày nghỉ: ${ngay.day}/${ngay.month}/${ngay.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: ngay,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setS(() => ngay = d);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lyDo,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Lý do nghỉ'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (lyDo.text.trim().isEmpty) {
      toast(context, 'Vui lòng nhập lý do', error: true);
      return;
    }
    final err = await ApiService.createDon({
      'sinhVienId': widget.svId,
      'lopHocPhanId': lopId,
      'ngayNghi': DateTime(ngay.year, ngay.month, ngay.day).toIso8601String(),
      'lyDo': lyDo.text.trim(),
      'minhChungUrl': '',
      'trangThai': 'ChoDuyet',
      'ngayGui': DateTime.now().toUtc().toIso8601String(),
      'phanHoiGiaoVien': '',
    });
    if (!mounted) return;
    if (err != null) {
      toast(context, err, error: true);
    } else {
      toast(context, 'Đã gửi đơn nghỉ phép');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.svId == null
          ? null
          : FloatingActionButton.extended(
          onPressed: _create, icon: const Icon(Icons.add), label: const Text('Gửi đơn')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Bạn chưa có đơn nào'))])
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: _items.length,
          itemBuilder: (_, i) {
            final m = _items[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.mail_outline, color: kPrimary),
                title: Text('Đơn #${m['id']} • ${m['trangThai'] ?? ''}'),
                subtitle: Text('Ngày nghỉ: ${fmtDate(m['ngayNghi'])}\nLý do: ${m['lyDo'] ?? ''}'
                    '${(m['phanHoiGiaoVien'] ?? '').toString().isEmpty ? '' : '\nPhản hồi: ${m['phanHoiGiaoVien']}'}'),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
    );
  }
}