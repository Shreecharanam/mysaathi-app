import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Student {
  String id;
  String name;
  String phone;
  String batch;
  double fee;

  Student({
    required this.id,
    required this.name,
    this.phone = '',
    this.batch = '',
    this.fee = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'batch': batch,
        'fee': fee,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        batch: (j['batch'] ?? '') as String,
        fee: ((j['fee'] ?? 0) as num).toDouble(),
      );
}

class AppStore extends ChangeNotifier {
  String centreName = '';
  final List<Student> students = [];
  final Map<String, List<String>> attendance = {};
  final Map<String, double> payments = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    centreName = prefs.getString('centreName') ?? '';
    final s = prefs.getString('students');
    if (s != null && s.isNotEmpty) {
      for (final e in (jsonDecode(s) as List)) {
        students.add(Student.fromJson(Map<String, dynamic>.from(e as Map)));
      }
    }
    final a = prefs.getString('attendance');
    if (a != null && a.isNotEmpty) {
      (jsonDecode(a) as Map).forEach((k, v) {
        attendance[k as String] = (v as List).map((x) => x as String).toList();
      });
    }
    final p = prefs.getString('payments');
    if (p != null && p.isNotEmpty) {
      (jsonDecode(p) as Map).forEach((k, v) {
        payments[k as String] = (v as num).toDouble();
      });
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('centreName', centreName);
    await prefs.setString(
        'students', jsonEncode(students.map((e) => e.toJson()).toList()));
    await prefs.setString('attendance', jsonEncode(attendance));
    await prefs.setString('payments', jsonEncode(payments));
    notifyListeners();
  }

  void setCentre(String name) {
    centreName = name;
    save();
  }

  void addStudent(Student s) {
    students.add(s);
    save();
  }

  void removeStudent(String id) {
    students.removeWhere((s) => s.id == id);
    save();
  }

  String monthKey(DateTime d) => '\${d.year}-\${d.month.toString().padLeft(2, '0')}';

  String todayKey(DateTime d) =>
      '\${d.year}-\${d.month.toString().padLeft(2, '0')}-\${d.day.toString().padLeft(2, '0')}';

  bool isPresent(String date, String studentId) =>
      (attendance[date] ?? <String>[]).contains(studentId);

  void toggleAttendance(String date, String studentId) {
    final list = attendance.putIfAbsent(date, () => <String>[]);
    if (list.contains(studentId)) {
      list.remove(studentId);
    } else {
      list.add(studentId);
    }
    save();
  }

  double paidFor(String studentId, String month) =>
      payments['\$studentId|\$month'] ?? 0;

  void setPaid(String studentId, String month, double amount) {
    payments['\$studentId|\$month'] = amount;
    save();
  }
}
