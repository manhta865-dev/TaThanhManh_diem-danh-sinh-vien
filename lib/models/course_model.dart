
class CourseModel {
  final int id;
  final String tenLopHocPhan;
  final String maLopHocPhan;
  final String? phongHoc;
  final String? giangVien;
  final String? hocKy;
  final String? namHoc;

  CourseModel({
    required this.id,
    required this.tenLopHocPhan,
    required this.maLopHocPhan,
    this.phongHoc,
    this.giangVien,
    this.hocKy,
    this.namHoc,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final monHoc = json['monHoc'] is Map
        ? Map<String, dynamic>.from(json['monHoc'])
        : <String, dynamic>{};

    return CourseModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      tenLopHocPhan: (json['tenLopHocPhan'] ??
          json['tenLop'] ??
          json['name'] ??
          monHoc['tenMon'] ??
          '')
          .toString(),
      maLopHocPhan:
      (json['maLopHocPhan'] ?? json['maLop'] ?? '').toString(),
      phongHoc: json['phongHoc']?.toString(),
      giangVien: json['giangVien']?.toString(),
      hocKy: json['hocKy']?.toString(),
      namHoc: json['namHoc']?.toString(),
    );
  }
}
