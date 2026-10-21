import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../utils.dart';

/// (f) Dịch ảnh chụp: chụp/chọn ảnh -> upload -> gọi API OCR + dịch
class OcrTab extends StatefulWidget {
  const OcrTab({super.key});

  @override
  State<OcrTab> createState() => _OcrTabState();
}

class _OcrTabState extends State<OcrTab> {
  final _picker = ImagePicker();
  File? _file;
  String _lang = 'vi';
  Map<String, dynamic>? _result;
  bool _busy = false;

  Future<void> _pick(ImageSource src) async {
    final x = await _picker.pickImage(source: src, imageQuality: 85);
    if (x != null) {
      setState(() {
        _file = File(x.path);
        _result = null;
      });
    }
  }

  Future<void> _translate() async {
    if (_file == null) return;
    setState(() => _busy = true);
    try {
      final up = await ApiService.uploadImage(_file!);
      if (up.url == null) {
        if (mounted) toast(context, up.error ?? 'Upload ảnh thất bại', error: true);
        return;
      }
      final r = await ApiService.dichAnh(up.url!, _lang);
      if (!mounted) return;
      if (r.error != null) {
        toast(context, r.error!, error: true);
      } else {
        setState(() => _result = r.data);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _block(String title, dynamic text, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      SelectableText('${text ?? ''}', style: TextStyle(fontSize: 15, color: color)),
    ]),
  );

  Widget _resultCard(Map<String, dynamic> d) {
    final k = d['ketQuaNhanDien'] is Map
        ? Map<String, dynamic>.from(d['ketQuaNhanDien'])
        : <String, dynamic>{};
    final dich = k['banDichTiengAnh'] ?? k['banDich'] ?? k['ketQua'] ?? d['raw'] ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.verified, color: kPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${d['message'] ?? 'Kết quả dịch'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          const Divider(height: 24),
          if (k['loaiGiayTo'] != null) _block('Loại giấy tờ', k['loaiGiayTo']),
          if (k['noiDungGoc'] != null) _block('Nội dung gốc', k['noiDungGoc']),
          _block('Bản dịch', dich, color: kPrimary),
          if (k['doChinhXac'] != null) _block('Độ chính xác', k['doChinhXac']),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _file == null
              ? const Center(child: Text('Chưa chọn ảnh'))
              : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_file!, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Chụp ảnh')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Chọn ảnh')),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _lang,
          decoration: const InputDecoration(labelText: 'Dịch sang ngôn ngữ'),
          items: const [
            DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ja', child: Text('日本語')),
            DropdownMenuItem(value: 'ko', child: Text('한국어')),
            DropdownMenuItem(value: 'zh', child: Text('中文')),
          ],
          onChanged: (v) => setState(() => _lang = v ?? 'vi'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: (_file == null || _busy) ? null : _translate,
          icon: _busy
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.translate),
          label: Text(_busy ? 'Đang xử lý...' : 'Dịch ảnh'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _resultCard(_result!),
        ],
      ],
    );
  }
}