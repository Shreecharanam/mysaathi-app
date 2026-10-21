import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const String appVersion = 'v7';

String periodKeyFor(DateTime d, String period) {
  final y = d.year;
  switch (period) {
    case 'yearly':
      return '$y';
    case 'half':
      return '$y-H${d.month <= 6 ? 1 : 2}';
    case 'quarterly':
      return '$y-Q${((d.month - 1) ~/ 3) + 1}';
    case 'once':
      return 'once';
    default:
      return '$y-${d.month.toString().padLeft(2, '0')}';
  }
}

String periodLabel(String p) => switch (p) {
      'yearly' => 'Yearly',
      'half' => 'Half-Yearly',
      'quarterly' => 'Quarterly',
      'once' => 'One-time',
      _ => 'Monthly',
    };

class Student {
  String id;
  String name;
  String phone;
  String batch;
  double fee;
  String joinDate;
  String feePeriod;

  Student({
    required this.id,
    required this.name,
    this.phone = '',
    this.batch = '',
    this.fee = 0,
    this.joinDate = '',
    this.feePeriod = 'monthly',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'batch': batch,
        'fee': fee,
        'joinDate': joinDate,
        'feePeriod': feePeriod,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        batch: (j['batch'] ?? '') as String,
        fee: ((j['fee'] ?? 0) as num).toDouble(),
        joinDate: (j['joinDate'] ?? '') as String,
        feePeriod: (j['feePeriod'] ?? 'monthly') as String,
      );
}

class AppStore extends ChangeNotifier {
  String accountKey = '';
  String centreName = '';
  String centreType = 'tuition';
  String upiId = '';
  String centrePhone = '';
  String? storageError;
  final List<Student> students = [];
  final Map<String, List<String>> attendance = {};
  final Map<String, double> payments = {};
  final Map<String, dynamic> accounts = {};

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

  void pullActive() {
    students.clear();
    attendance.clear();
    payments.clear();
    final d = accounts[accountKey];
    if (d is Map) {
      centreName = (d['centreName'] ?? '') as String;
      centreType = (d['centreType'] ?? 'tuition') as String;
      upiId = (d['upiId'] ?? '') as String;
      centrePhone = (d['centrePhone'] ?? '') as String;
      for (final e in ((d['students'] ?? []) as List)) {
        students.add(Student.fromJson(Map<String, dynamic>.from(e as Map)));
      }
      ((d['attendance'] ?? {}) as Map).forEach((k, v) {
        attendance[k as String] = (v as List).map((x) => x as String).toList();
      });
      ((d['payments'] ?? {}) as Map).forEach((k, v) {
        payments[k as String] = (v as num).toDouble();
      });
    }
  }

  Future<void> load() async {
    try {
      final f = await dataFile();
      if (f != null && f.existsSync()) {
        final txt = f.readAsStringSync();
        if (txt.trim().isNotEmpty) {
          final m = jsonDecode(txt);
          if (m is Map && m['accounts'] is Map) {
            accounts.clear();
            (m['accounts'] as Map).forEach((k, v) => accounts[k.toString()] = v);
            final last = (m['last'] ?? '').toString();
            if (last.isNotEmpty && accounts.containsKey(last)) {
              accountKey = last;
              pullActive();
            }
          }
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
      if (accountKey.isNotEmpty) {
        accounts[accountKey] = {
          'centreName': centreName,
          'centreType': centreType,
          'upiId': upiId,
          'centrePhone': centrePhone,
          'students': students.map((e) => e.toJson()).toList(),
          'attendance': attendance,
          'payments': payments,
        };
      }
      final f = await dataFile();
      if (f == null) {
        return;
      }
      f.writeAsStringSync(jsonEncode({'last': accountKey, 'accounts': accounts}));
    } catch (e) {
      storageError = e.toString();
    }
  }

  void login(String name, String type) {
    final key = name.trim().toLowerCase();
    accountKey = key;
    if (accounts[key] is Map) {
      pullActive();
    } else {
      centreName = name;
      centreType = type;
      upiId = '';
      centrePhone = '';
      students.clear();
      attendance.clear();
      payments.clear();
    }
    save();
  }

  void logout() {
    accountKey = '';
    centreName = '';
    centreType = 'tuition';
    upiId = '';
    centrePhone = '';
    students.clear();
    attendance.clear();
    payments.clear();
    save();
  }

  void setPayments(String upi, String phone) {
    upiId = upi;
    centrePhone = phone;
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

  double paidFor(String studentId, String periodKey) =>
      payments['$studentId|$periodKey'] ?? 0;

  void setPaid(String studentId, String periodKey, double amount) {
    payments['$studentId|$periodKey'] = amount;
    save();
  }
}
