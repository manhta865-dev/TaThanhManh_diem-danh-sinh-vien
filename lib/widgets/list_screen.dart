import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Màn hình danh sách chỉ đọc, dùng để xem dữ liệu từ 1 endpoint GET.
class ListScreen extends StatefulWidget {
  final String title;
  final String path;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;
  final IconData icon;

  const ListScreen({
    super.key,
    required this.title,
    required this.path,
    required this.titleOf,
    required this.subtitleOf,
    this.icon = Icons.person,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ApiService.getList(widget.path);
    if (!mounted) return;
    setState(() {
      _items = r.items;
      _error = r.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Chưa có dữ liệu'))])
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _items.length,
          itemBuilder: (_, i) => Card(
            child: ListTile(
              leading: Icon(widget.icon),
              title: Text(widget.titleOf(_items[i])),
              subtitle: Text(widget.subtitleOf(_items[i])),
            ),
          ),
        ),
      ),
    );
  }
}