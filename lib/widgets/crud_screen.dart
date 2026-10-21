import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils.dart';

enum FieldKind { text, number, date, time, select }

class FieldDef {
  final String key;
  final String label;
  final FieldKind kind;
  final String? optionsEndpoint; // dùng cho kind = select
  final List<String> labelKeys; // field dùng làm nhãn trong danh sách chọn

  const FieldDef(this.key, this.label,
      {this.kind = FieldKind.text, this.optionsEndpoint, this.labelKeys = const ['id']});
}

class CrudScreen extends StatefulWidget {
  final String title;
  final String endpoint;
  final List<FieldDef> fields;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>)? subtitleOf;
  final bool allowAdd, allowEdit, allowDelete, showAppBar;
  final List<Widget> Function(BuildContext ctx, Map<String, dynamic> item, Future<void> Function() reload)? actions;

  const CrudScreen({
    super.key,
    required this.title,
    required this.endpoint,
    required this.fields,
    required this.titleOf,
    this.subtitleOf,
    this.allowAdd = true,
    this.allowEdit = true,
    this.allowDelete = true,
    this.showAppBar = true,
    this.actions,
  });

  @override
  State<CrudScreen> createState() => _CrudScreenState();
}

class _CrudScreenState extends State<CrudScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ApiService.getList(widget.endpoint);
    if (!mounted) return;
    setState(() {
      _items = r.items;
      _error = r.error;
      _loading = false;
    });
  }

  String _sub(Map<String, dynamic> m) => widget.subtitleOf?.call(m) ?? summarize(m);

  String _initText(FieldDef f, dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    if (f.kind == FieldKind.date && s.length >= 10) return s.substring(0, 10);
    return s;
  }

  Future<void> _form([Map<String, dynamic>? item]) async {
    // Tải danh sách cho các ô chọn (khóa ngoại)
    final opts = <String, List<Map<String, dynamic>>>{};
    for (final f in widget.fields) {
      if (f.kind == FieldKind.select && f.optionsEndpoint != null) {
        opts[f.key] = (await ApiService.getList(f.optionsEndpoint!)).items;
      }
    }
    if (!mounted) return;

    final ctrls = {
      for (final f in widget.fields) f.key: TextEditingController(text: _initText(f, item?[f.key]))
    };
    final sel = <String, int?>{
      for (final f in widget.fields)
        if (f.kind == FieldKind.select) f.key: int.tryParse('${item?[f.key]}')
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(item == null ? 'Thêm ${widget.title}' : 'Sửa ${widget.title}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _input(ctx, f, ctrls[f.key]!, opts[f.key] ?? const [], sel, setS),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    // Gom dữ liệu trước khi giải phóng controller
    final body = item == null ? <String, dynamic>{} : ApiService.cleanBody(item);
    for (final f in widget.fields) {
      if (f.kind == FieldKind.select) {
        if (sel[f.key] != null) body[f.key] = sel[f.key];
        continue;
      }
      final t = ctrls[f.key]!.text.trim();
      if (t.isEmpty) continue;
      switch (f.kind) {
        case FieldKind.number:
          body[f.key] = num.tryParse(t) ?? t;
        case FieldKind.date:
          body[f.key] = '${t}T00:00:00';
        default:
          body[f.key] = t;
      }
    }
    if (ok != true || !mounted) return;

    final err = item == null
        ? await ApiService.create(widget.endpoint, body)
        : await ApiService.update(widget.endpoint, item['id'], body);
    if (!mounted) return;
    if (err != null) {
      toast(context, err, error: true);
    } else {
      toast(context, item == null ? 'Đã thêm' : 'Đã cập nhật');
      _load();
    }
  }

  Widget _input(BuildContext ctx, FieldDef f, TextEditingController c, List<Map<String, dynamic>> options,
      Map<String, int?> sel, StateSetter setS) {
    switch (f.kind) {
      case FieldKind.select:
        final ids = options.map((m) => int.tryParse('${m['id']}')).toList();
        return DropdownButtonFormField<int>(
          value: ids.contains(sel[f.key]) ? sel[f.key] : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: [
            for (final m in options)
              DropdownMenuItem<int>(
                value: int.tryParse('${m['id']}'),
                child: Text('${pick(m, f.labelKeys) ?? 'Mục #${m['id']}'}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setS(() => sel[f.key] = v),
        );
      case FieldKind.date:
        return TextField(
          controller: c,
          readOnly: true,
          decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today)),
          onTap: () async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setS(() => c.text =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
            }
          },
        );
      case FieldKind.time:
        return TextField(
          controller: c,
          readOnly: true,
          decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.access_time)),
          onTap: () async {
            final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 7, minute: 0));
            if (t != null) {
              setS(() => c.text =
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00');
            }
          },
        );
      case FieldKind.number:
        return TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: f.label),
        );
      case FieldKind.text:
        return TextField(controller: c, decoration: InputDecoration(labelText: f.label));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa "${widget.titleOf(item)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await ApiService.remove(widget.endpoint, item['id']);
    if (!mounted) return;
    if (err != null) {
      toast(context, err, error: true);
    } else {
      toast(context, 'Đã xóa');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _items.where((m) {
      if (_q.isEmpty) return true;
      return '${widget.titleOf(m)} ${_sub(m)}'.toLowerCase().contains(_q.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
      floatingActionButton: widget.allowAdd
          ? FloatingActionButton(onPressed: () => _form(), child: const Icon(Icons.add))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                  hintText: 'Tìm kiếm...', prefixIcon: Icon(Icons.search), isDense: true),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ]),
              ),
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: shown.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Chưa có dữ liệu'))])
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: shown.length,
                itemBuilder: (ctx, i) {
                  final m = shown[i];
                  final extra = widget.actions?.call(ctx, m, _load) ?? [];
                  return Card(
                    child: Column(children: [
                      ListTile(
                        title: Text(widget.titleOf(m),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_sub(m), maxLines: 4, overflow: TextOverflow.ellipsis),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (widget.allowEdit)
                            IconButton(
                                icon: const Icon(Icons.edit, color: kPrimary),
                                onPressed: () => _form(m)),
                          if (widget.allowDelete)
                            IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _delete(m)),
                        ]),
                      ),
                      if (extra.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8, right: 8),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(spacing: 8, runSpacing: 4, children: extra)),
                        ),
                    ]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}