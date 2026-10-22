import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils.dart';

class StatsTab extends StatefulWidget {
  final int? svId;
  const StatsTab({super.key, required this.svId});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  List<Map<String, dynamic>> _mons = [];
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
    final r = await ApiService.getJson('/api/ThongKe/sinh-vien/${widget.svId}');
    if (!mounted) return;
    final d = r.data;
    final list = <Map<String, dynamic>>[];
    if (d is Map && d['cacMonHoc'] is List) {
      for (final e in d['cacMonHoc']) {
        if (e is Map) list.add(Map<String, dynamic>.from(e));
      }
    }
    setState(() {
      _mons = list;
      _error = r.error;
      _loading = false;
    });
  }

  Color _color(double v) => v >= 20 ? Colors.red : (v >= 15 ? Colors.orange : Colors.green);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const GradientHeader(
            title: 'Thống kê của tôi',
            subtitle: 'Tỉ lệ vắng theo từng môn',
            icon: Icons.insights,
          ),
          const SectionTitle('Các môn học', sub: 'Vắng từ 20% trở lên có nguy cơ bị cấm thi'),
          if (_mons.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Bạn chưa thuộc lớp học phần nào'))),
          for (final m in _mons) _card(m),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final ti = ((m['tiLeVang'] is num) ? (m['tiLeVang'] as num).toDouble() : 0.0).clamp(0.0, 100.0);
    final c = _color(ti);
    final danger = ti >= 20;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${m['tenMon'] ?? ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (danger)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Text('Nguy cơ cấm thi',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
          Text('${m['maLopHocPhan'] ?? ''}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (ti / 100).clamp(0.0, 1.0),
              minHeight: 10,
              color: c,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 6),
          Text('Tỉ lệ vắng: ${ti.toStringAsFixed(ti == ti.roundToDouble() ? 0 : 1)}%',
              style: TextStyle(color: c, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Đã mở', '${m['tongBuoiDaMo'] ?? 0}', Colors.blueGrey),
            _chip('Có mặt', '${m['soBuoiCoMat'] ?? 0}', Colors.green),
            _chip('Vắng có phép', '${m['soBuoiVangCoPhep'] ?? 0}', Colors.orange),
            _chip('Vắng không phép', '${m['soBuoiVangKhongPhep'] ?? 0}', Colors.red),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String label, String value, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Text('$label: $value', style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w600)),
  );
}