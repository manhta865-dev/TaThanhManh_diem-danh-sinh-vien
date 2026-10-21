import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class ApiService {
  static const _timeout = Duration(seconds: 25);

  static String get baseUrl {
    final u = dotenv.env['BASE_URL'] ?? '';
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  // ---------- Token ----------
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString('token');

  static Future<void> saveToken(String t) async =>
      (await SharedPreferences.getInstance()).setString('token', t);

  static Future<void> logout() async =>
      (await SharedPreferences.getInstance()).remove('token');

  // ---------- Helpers ----------
  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _error(http.Response r) {
    final d = _decode(r.body);
    if (d is Map) {
      final errs = d['errors'];
      if (errs is Map && errs.isNotEmpty) {
        return errs.values.map((v) => v is List ? v.join(', ') : '$v').join('\n');
      }
      final m = d['thongBao'] ?? d['message'] ?? d['error'] ?? d['title'] ?? d['detail'];
      if (m != null) return m.toString();
    } else if (d is String && d.isNotEmpty && d.length < 200 && !d.contains('<')) {
      return d;
    }
    if (r.statusCode == 401) return 'Chưa đăng nhập hoặc phiên đã hết hạn (401)';
    if (r.statusCode == 403) return 'Bạn không có quyền thực hiện (403)';
    return 'Lỗi ${r.statusCode}';
  }

  static List<Map<String, dynamic>> _toList(dynamic d) {
    if (d is List) {
      return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (d is Map) {
      for (final k in ['data', 'items', 'result', 'results', '\$values']) {
        if (d[k] != null) return _toList(d[k]);
      }
    }
    return [];
  }

  /// Bỏ các field lồng nhau (Map/List) trước khi gửi PUT/POST lại.
  static Map<String, dynamic> cleanBody(Map<String, dynamic> m) {
    final r = <String, dynamic>{};
    m.forEach((k, v) {
      if (v is! Map && v is! List) r[k] = v;
    });
    return r;
  }

  /// Trả về null nếu OK, ngược lại là thông báo lỗi.
  static Future<String?> _send(String method, String path, {Object? body}) async {
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers.addAll(_headers(token: await getToken()));
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(await req.send().timeout(_timeout));
      debugPrint('$method $path -> ${res.statusCode} ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) return _error(res);
      final d = _decode(res.body);
      if (d is Map &&
          (d['status'] == false || d['success'] == false || d['thanhCong'] == false)) {
        return (d['thongBao'] ?? d['message'] ?? 'Server từ chối yêu cầu').toString();
      }
      return null;
    } catch (e) {
      return 'Không kết nối được server: $e';
    }
  }

  static Future<({dynamic data, String? error})> getJson(String path) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token: await getToken()))
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (data: _decode(res.body), error: null);
      }
      debugPrint('GET $path -> ${res.statusCode} ${res.body}');
      return (data: null, error: _error(res));
    } catch (e) {
      return (data: null, error: 'Không kết nối được server: $e');
    }
  }

  static Future<({List<Map<String, dynamic>> items, String? error})> getList(String path) async {
    final r = await getJson(path);
    return (items: r.error == null ? _toList(r.data) : <Map<String, dynamic>>[], error: r.error);
  }

  // ---------- Xác thực ----------
  static Future<String?> register(Map<String, dynamic> body) =>
      _send('POST', '/api/Authenticate/register', body: body);

  static String? _findOtp(dynamic d) {
    final re = RegExp(r'(?<!\d)\d{6}(?!\d)');
    if (d is Map) {
      for (final k in ['otp', 'Otp', 'OTP', 'otpCode', 'maOtp', 'code']) {
        if (d[k] != null) {
          final m = re.firstMatch(d[k].toString());
          if (m != null) return m.group(0);
        }
      }
      if (d['data'] != null) {
        final r = _findOtp(d['data']);
        if (r != null) return r;
      }
      for (final v in d.values) {
        if (v is String) {
          final m = re.firstMatch(v);
          if (m != null) return m.group(0);
        }
      }
    } else if (d is String) {
      return re.firstMatch(d)?.group(0);
    }
    return null;
  }

  static Future<({String? otp, String? info, String? error})> requestOtp(
      String user, String pass) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/api/Authenticate/request-otp'),
          headers: _headers(), body: jsonEncode({'username': user, 'password': pass}))
          .timeout(_timeout);
      debugPrint('request-otp -> ${res.statusCode} ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (otp: null, info: null, error: _error(res));
      }
      final d = _decode(res.body);
      String? info;
      if (d is Map && d['message'] != null) {
        info = d['message'].toString();
      } else if (d is String) {
        info = d;
      } else {
        info = res.body;
      }
      return (otp: _findOtp(d), info: info, error: null);
    } catch (e) {
      return (otp: null, info: null, error: 'Không kết nối được server: $e');
    }
  }

  static Future<String?> login(String user, String pass, String otp) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/api/Authenticate/login'),
          headers: _headers(),
          body: jsonEncode({'username': user, 'password': pass, 'otp': otp}))
          .timeout(_timeout);
      debugPrint('login -> ${res.statusCode}');
      if (res.statusCode != 200) return _error(res);
      final d = _decode(res.body);
      String? token;
      if (d is Map) {
        final t = d['token'] ??
            d['accessToken'] ??
            d['jwt'] ??
            (d['data'] is Map ? (d['data']['token'] ?? d['data']['accessToken']) : null);
        token = t?.toString();
        if (d['status'] == false) return (d['message'] ?? 'Đăng nhập thất bại').toString();
      } else if (d is String && d.split('.').length == 3) {
        token = d;
      }
      if (token == null || token.isEmpty) {
        return 'Đăng nhập thành công nhưng không tìm thấy token trong phản hồi';
      }
      await saveToken(token);
      return null;
    } catch (e) {
      return 'Không kết nối được server: $e';
    }
  }

  static Future<UserModel?> getMe() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/Authenticate/me'), headers: _headers(token: token))
          .timeout(_timeout);
      debugPrint('me -> ${res.statusCode} ${res.body}');
      if (res.statusCode == 401) {
        await logout();
        return null;
      }
      if (res.statusCode == 200) {
        final d = _decode(res.body);
        if (d is Map) {
          return UserModel.fromJson(Map<String, dynamic>.from(d['data'] is Map ? d['data'] : d));
        }
      }
    } catch (e) {
      debugPrint('getMe lỗi: $e');
    }
    try {
      if (JwtDecoder.isExpired(token)) return null;
      return UserModel.fromJson(JwtDecoder.decode(token));
    } catch (_) {
      return null;
    }
  }

  // ---------- CRUD dùng chung ----------
  static Future<String?> create(String endpoint, Map<String, dynamic> body) =>
      _send('POST', endpoint, body: body);

  /// PUT cần body có id trùng id trên URL.
  static Future<String?> update(String endpoint, dynamic id, Map<String, dynamic> body) =>
      _send('PUT', '$endpoint/$id', body: {...body, 'id': id});

  static Future<String?> remove(String endpoint, dynamic id) => _send('DELETE', '$endpoint/$id');

  // ---------- Buổi điểm danh / điểm danh ----------
  static Future<String?> toggleDongMo(dynamic id) => _send('PUT', '/api/BuoiDiemDanh/$id/dong-mo');

  /// Trả về nguyên response của server: thanhCong, thongBao, trangThai, khoangCachMet...
  static Future<Map<String, dynamic>> checkInRaw({
    required int buoiId,
    required String maSv,
    required double lat,
    required double lng,
    String phuongThuc = 'GPS+VANTAY',
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/api/DiemDanh/check-in'),
          headers: _headers(token: await getToken()),
          body: jsonEncode({
            'buoiDiemDanhId': buoiId,
            'maSV': maSv,
            'maQRCode': '',
            'viTriViDo': lat,
            'viTriKinhDo': lng,
            'phuongThuc': phuongThuc,
            'anhMinhChung': '',
            'ghiChu': '',
          }))
          .timeout(_timeout);
      debugPrint('check-in -> ${res.statusCode} ${res.body}');
      final d = _decode(res.body);
      if (d is Map) return Map<String, dynamic>.from(d);
      return {'thanhCong': false, 'thongBao': _error(res)};
    } catch (e) {
      return {'thanhCong': false, 'thongBao': 'Không kết nối được server: $e'};
    }
  }

  // ---------- Sinh viên ----------
  static Future<Map<String, dynamic>?> getSinhVienByMaSv(String maSv) async {
    final r = await getJson('/api/SinhVien/by-masv/$maSv');
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d['data'] is Map ? d['data'] : d);
    return null;
  }

  /// Nếu chưa có hồ sơ SinhVien cho tài khoản này thì tạo mới rồi trả về.
  static Future<Map<String, dynamic>?> ensureSinhVien(UserModel u) async {
    final maSv = u.maSv ?? u.username;
    final sv = await getSinhVienByMaSv(maSv);
    if (sv != null) return sv;

    String? uid;
    try {
      final c = JwtDecoder.decode((await getToken())!);
      uid = (c['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
          c['nameid'] ??
          c['sub'] ??
          c['uid'])
          ?.toString();
    } catch (_) {}

    final err = await _send('POST', '/api/SinhVien', body: {
      'maSV': maSv,
      'hoTen': u.hoTen ?? u.username,
      'email': u.email ?? '',
      'lop': '',
      'khoa': '',
      'soDienThoai': '',
      'trangThai': true,
      if (uid != null) 'userId': uid,
    });
    if (err != null) {
      debugPrint('Tạo SinhVien lỗi: $err');
      return null;
    }
    return getSinhVienByMaSv(maSv);
  }

  // ---------- Sinh viên trong lớp học phần ----------
  static Future<String?> themSinhVienVaoLop(int lopId, int svId) =>
      _send('POST', '/api/LopHocPhan/$lopId/them-sinh-vien/$svId');

  static Future<String?> xoaSinhVienKhoiLop(int lopId, int svId) =>
      _send('DELETE', '/api/LopHocPhan/$lopId/xoa-sinh-vien/$svId');

  // ---------- Đơn nghỉ phép ----------
  static Future<String?> createDon(Map<String, dynamic> body) =>
      _send('POST', '/api/DonNghiPhep', body: body);

  static Future<String?> duyetDon(dynamic id, Map<String, dynamic> body) =>
      _send('PUT', '/api/DonNghiPhep/$id/duyet', body: body);

  // ---------- Upload + dịch ảnh ----------
  static Future<({String? url, String? error})> uploadImage(File file) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/Upload/anh-minh-chung'));
      req.headers.addAll(_headers(token: await getToken())..remove('Content-Type'));
      req.files.add(await http.MultipartFile.fromPath('file', file.path));
      final res =
      await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
      debugPrint('upload -> ${res.statusCode} ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) return (url: null, error: _error(res));
      final d = _decode(res.body);
      String? url;
      if (d is Map) {
        final inner = d['data'];
        url = (d['url'] ??
            d['imageUrl'] ??
            d['fileUrl'] ??
            d['path'] ??
            (inner is Map ? (inner['url'] ?? inner['imageUrl']) : inner))
            ?.toString();
      } else if (d is String && d.isNotEmpty) {
        url = d;
      }
      if (url == null) return (url: null, error: 'Không đọc được đường dẫn ảnh: ${res.body}');
      if (!url.startsWith('http')) url = '$baseUrl${url.startsWith('/') ? '' : '/'}$url';
      return (url: url, error: null);
    } catch (e) {
      return (url: null, error: 'Lỗi upload: $e');
    }
  }

  /// Trả về nguyên JSON của server (status, message, imageUrl, ketQuaNhanDien...).
  static Future<({Map<String, dynamic>? data, String? error})> dichAnh(
      String imageUrl, String ngon) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/api/Upload/dich-anh-ocr'),
          headers: _headers(token: await getToken()),
          body: jsonEncode({'imageUrl': imageUrl, 'ngonNguDich': ngon}))
          .timeout(const Duration(seconds: 90));
      debugPrint('dich-anh -> ${res.statusCode} ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) return (data: null, error: _error(res));
      final d = _decode(res.body);
      if (d is Map) return (data: Map<String, dynamic>.from(d), error: null);
      return (data: {'raw': d.toString()}, error: null);
    } catch (e) {
      return (data: null, error: 'Lỗi dịch ảnh: $e');
    }
  }
}