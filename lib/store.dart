import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const String appVersion = 'v5';

class Student {
  String id;
  String name;
  String phone;
  String batch;
  double fee;
  String joinDate;

  Student({
    required this.id,
    required this.name,
    this.phone = '',
    this.batch = '',
    this.fee = 0,
    this.joinDate = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'batch': batch,
        'fee': fee,
        'joinDate': joinDate,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        batch: (j['batch'] ?? '') as String,
        fee: ((j['fee'] ?? 0) as num).toDouble(),
        joinDate: (j['joinDate'] ?? '') as String,
      );
}

class AppStore extends ChangeNotifier {
  String centreName = '';
  String centreType = 'tuition';
  String? storageError;
  final List<Student> students = [];
  final Map<String, List<String>> attendance = {};
  final Map<String, double> payments = {};

  File? _file;

  Future<File?> dataFile() async {
    if (_file != null) {
      return _file;
    }
    final dirs = <String>[
      '/data/data/com.mysaathi.mysaathi/files',
      '/data/user/0/com.mysaathi.mysaathi/files',
    ];
    for (final p in dirs) {
      try {
        final d = Directory(p);
        if (!d.existsSync()) {
          d.createSync(recursive: true);
        }
        final f = File('${d.path}/mysaathi_data.json');
        if (!f.existsSync()) {
          f.writeAsStringSync('{}');
        }
        _file = f;
        storageError = null;
        return f;
      } catch (e) {
        storageError = e.toString();
      }
    }
    try {
      final d = Directory.systemTemp;
      final f = File('${d.path}/mysaathi_data.json');
      if (!f.existsSync()) {
        f.writeAsStringSync('{}');
      }
      _file = f;
      return f;
    } catch (e) {
      storageError = e.toString();
    }
    return null;
  }

  Future<void> load() async {
    try {
      final f = await dataFile();
      if (f != null && f.existsSync()) {
        final txt = f.readAsStringSync();
        if (txt.trim().isNotEmpty) {
          final m = jsonDecode(txt) as Map<String, dynamic>;
          centreName = (m['centreName'] ?? '') as String;
          centreType = (m['centreType'] ?? 'tuition') as String;
          students.clear();
          for (final e in ((m['students'] ?? []) as List)) {
            students.add(Student.fromJson(Map<String, dynamic>.from(e as Map)));
          }
          attendance.clear();
          ((m['attendance'] ?? {}) as Map).forEach((k, v) {
            attendance[k as String] =
                (v as List).map((x) => x as String).toList();
          });
          payments.clear();
          ((m['payments'] ?? {}) as Map).forEach((k, v) {
            payments[k as String] = (v as num).toDouble();
          });
        }
      }
    } catch (e) {
      storageError = e.toString();
    }
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final f = await dataFile();
      if (f == null) {
        return;
      }
      final m = <String, dynamic>{
        'centreName': centreName,
        'centreType': centreType,
        'students': students.map((e) => e.toJson()).toList(),
        'attendance': attendance,
        'payments': payments,
      };
      f.writeAsStringSync(jsonEncode(m));
    } catch (e) {
      storageError = e.toString();
    }
  }

  void setCentre(String name, String type) {
    centreName = name;
    centreType = type;
    save();
  }

  String personWord() => switch (centreType) {
        'gym' => 'Member',
        'clinic' => 'Patient',
        'shop' => 'Customer',
        'other' => 'Person',
        _ => 'Student',
      };

  String personWordPlural() => switch (centreType) {
        'gym' => 'Members',
        'clinic' => 'Patients',
        'shop' => 'Customers',
        'other' => 'People',
        _ => 'Students',
      };

  String groupWord() => switch (centreType) {
        'gym' => 'Plan',
        'clinic' => 'Case',
        'shop' => 'Item',
        'other' => 'Group',
        _ => 'Batch',
      };

  String feeWord() => switch (centreType) {
        'clinic' => 'Fee',
        'shop' => 'Amount',
        'other' => 'Amount',
        _ => 'Monthly Fee',
      };

  void addStudent(Student s) {
    students.add(s);
    save();
  }

  void removeStudent(String id) {
    students.removeWhere((s) => s.id == id);
    save();
  }

  String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

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
      payments['$studentId|$month'] ?? 0;

  void setPaid(String studentId, String month, double amount) {
    payments['$studentId|$month'] = amount;
    save();
  }
}
