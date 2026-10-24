import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lang.dart';

const String appVersion = 'v15';

String stampDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

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
  String uid = '';
  String sessionUid = '';
  String accountKey = '';
  String lastCid = '';
  bool firebaseReady = false;
  String? firebaseError;
  String? cloudError;
  String cloudStatus = 'off';
  String centreName = '';
  String centreType = 'tuition';
  String upiId = '';
  String centrePhone = '';
  String gstin = '';
  String shopAddress = '';
  String lang = 'en';
  String? storageError;
  final List<Student> students = [];
  final Map<String, List<String>> attendance = {};
  final Map<String, double> payments = {};
  final Map<String, List<Map<String, String>>> notes = {};
  final List<Map<String, dynamic>> bills = [];
  final Map<String, dynamic> accounts = {};
  String _fileUid = '';

  File? _file;

  void refresh() {
    notifyListeners();
  }

  bool get loggedIn => uid.isNotEmpty;
  bool get centreOpen => accountKey.isNotEmpty;
  bool get isShop => centreType == 'shop';

  Map<String, dynamic> centreMap() => {
        'centreName': centreName,
        'centreType': centreType,
        'upiId': upiId,
        'centrePhone': centrePhone,
        'gstin': gstin,
        'shopAddress': shopAddress,
        'students': students.map((e) => e.toJson()).toList(),
        'attendance': attendance,
        'payments': payments,
        'notes': notes,
        'bills': bills,
      };

  void capture() {
    if (accountKey.isNotEmpty) {
      accounts[accountKey] = centreMap();
    }
  }

  void applyMap(Map<String, dynamic> d) {
    students.clear();
    attendance.clear();
    payments.clear();
    notes.clear();
    bills.clear();
    centreName = (d['centreName'] ?? '') as String;
    centreType = (d['centreType'] ?? 'tuition') as String;
    upiId = (d['upiId'] ?? '') as String;
    centrePhone = (d['centrePhone'] ?? '') as String;
    gstin = (d['gstin'] ?? '') as String;
    shopAddress = (d['shopAddress'] ?? '') as String;
    for (final e in ((d['students'] ?? []) as List)) {
      students.add(Student.fromJson(Map<String, dynamic>.from(e as Map)));
    }
    ((d['attendance'] ?? {}) as Map).forEach((k, v) {
      attendance[k as String] = (v as List).map((x) => x as String).toList();
    });
    ((d['payments'] ?? {}) as Map).forEach((k, v) {
      payments[k as String] = (v as num).toDouble();
    });
    ((d['notes'] ?? {}) as Map).forEach((k, v) {
      final list = <Map<String, String>>[];
      for (final e in (v as List)) {
        list.add(Map<String, String>.from(e as Map));
      }
      notes[k.toString()] = list;
    });
    for (final e in ((d['bills'] ?? []) as List)) {
      bills.add(Map<String, dynamic>.from(e as Map));
    }
  }

  void pullActive() {
    final d = accounts[accountKey];
    if (d is Map) {
      applyMap(Map<String, dynamic>.from(d));
    }
  }

  List<String> centreIds() => accounts.keys.toList();

  String centreLabel(String cid) {
    final d = accounts[cid];
    if (d is Map) {
      return (d['centreName'] ?? 'My Centre').toString();
    }
    return 'My Centre';
  }

  String centreTypeOf(String cid) {
    final d = accounts[cid];
    if (d is Map) {
      return (d['centreType'] ?? 'tuition').toString();
    }
    return 'tuition';
  }

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

  Future<void> _writeLocal() async {
    try {
      final f = await dataFile();
      if (f != null) {
        f.writeAsStringSync(jsonEncode({
          'uid': uid,
          'centres': accounts,
          'last': lastCid,
        }));
      }
    } catch (e) {
      storageError = e.toString();
    }
  }

  Future<void> load() async {
    try {
      final f = await dataFile();
      if (f != null && f.existsSync()) {
        final txt = f.readAsStringSync();
        if (txt.trim().isNotEmpty) {
          final m = jsonDecode(txt);
          if (m is Map && m['centres'] is Map) {
            final fileUid = (m['uid'] ?? '').toString();
            final want = sessionUid.isNotEmpty ? sessionUid : fileUid;
            if (want.isEmpty || fileUid.isEmpty || fileUid == want) {
              accounts.clear();
              (m['centres'] as Map)
                  .forEach((k, v) => accounts[k.toString()] = v);
              _fileUid = fileUid;
              uid = want.isNotEmpty ? want : fileUid;
              lastCid = (m['last'] ?? '').toString();
              if (lastCid.isNotEmpty && accounts.containsKey(lastCid)) {
                accountKey = lastCid;
                pullActive();
              }
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
    capture();
    notifyListeners();
    await _writeLocal();
    pushCloud();
  }

  Future<void> pushCloud() async {
    if (!firebaseReady || uid.isEmpty) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('centres').doc(uid).set({
        'centres': accounts,
        'last': lastCid,
      });
      cloudStatus = 'saved';
      cloudError = null;
    } catch (e) {
      cloudError = e.toString();
      cloudStatus = 'error';
    }
    notifyListeners();
  }

  Future<void> pullCloud() async {
    if (!firebaseReady || uid.isEmpty) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('centres')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        accounts.clear();
        ((d['centres'] ?? {}) as Map)
            .forEach((k, v) => accounts[k.toString()] = v);
        lastCid = (d['last'] ?? '').toString();
        _fileUid = uid;
        cloudStatus = 'restored';
      } else {
        cloudStatus = 'empty';
      }
      cloudError = null;
    } catch (e) {
      cloudError = e.toString();
      cloudStatus = 'error';
    }
    notifyListeners();
  }

  Future<void> loginWithUid(String u, String name, String type) async {
    uid = u;
    sessionUid = u;
    if (_fileUid != u) {
      accounts.clear();
      accountKey = '';
      lastCid = '';
      await pullCloud();
    }
    if (accounts.isEmpty) {
      await createCentre(name.isEmpty ? 'My Centre' : name, type);
      return;
    }
    if (lastCid.isNotEmpty && accounts.containsKey(lastCid)) {
      accountKey = lastCid;
    } else {
      accountKey = accounts.keys.first;
    }
    pullActive();
    lastCid = accountKey;
    await save();
  }

  Future<void> loginLocal(String name, String type) async {
    final key = name.trim().toLowerCase();
    uid = key;
    sessionUid = key;
    if (_fileUid != key) {
      accounts.clear();
      accountKey = '';
      lastCid = '';
    }
    if (accounts.isEmpty) {
      await createCentre(name, type);
      return;
    }
    if (lastCid.isNotEmpty && accounts.containsKey(lastCid)) {
      accountKey = lastCid;
    } else {
      accountKey = accounts.keys.first;
    }
    pullActive();
    lastCid = accountKey;
    await save();
  }

  Future<void> createCentre(String name, String type) async {
    capture();
    final cid = DateTime.now().microsecondsSinceEpoch.toString();
    accountKey = cid;
    lastCid = cid;
    centreName = name.isEmpty ? 'My Centre' : name;
    centreType = type;
    upiId = '';
    centrePhone = '';
    gstin = '';
    shopAddress = '';
    students.clear();
    attendance.clear();
    payments.clear();
    notes.clear();
    bills.clear();
    await save();
  }

  Future<void> switchTo(String cid) async {
    capture();
    accountKey = cid;
    lastCid = cid;
    pullActive();
    await save();
  }

  Future<void> openChooser() async {
    capture();
    accountKey = '';
    await save();
  }

  Future<void> removeCentre(String cid) async {
    accounts.remove(cid);
    if (accountKey == cid) {
      accountKey = '';
    }
    if (lastCid == cid) {
      lastCid = '';
    }
    await save();
  }

  Future<void> clearCentreData() async {
    students.clear();
    attendance.clear();
    payments.clear();
    notes.clear();
    bills.clear();
    await save();
  }

  Future<void> deleteAccount() async {
    accounts.clear();
    students.clear();
    attendance.clear();
    payments.clear();
    notes.clear();
    bills.clear();
    centreName = '';
    centreType = 'tuition';
    upiId = '';
    centrePhone = '';
    gstin = '';
    shopAddress = '';
    accountKey = '';
    lastCid = '';
    uid = '';
    sessionUid = '';
    _fileUid = '';
    await save();
  }

  Future<void> logout() async {
    uid = '';
    accountKey = '';
    lastCid = '';
    centreName = '';
    centreType = 'tuition';
    upiId = '';
    centrePhone = '';
    gstin = '';
    shopAddress = '';
    students.clear();
    attendance.clear();
    payments.clear();
    notes.clear();
    bills.clear();
    cloudStatus = 'off';
    await save();
  }

  void setLang(String l) {
    lang = l;
    gLang = l;
    save();
    notifyListeners();
  }

  void setPayments(String upi, String phone, String g, String addr) {
    upiId = upi;
    centrePhone = phone;
    gstin = g;
    shopAddress = addr;
    save();
  }

  String personWord() => switch (centreType) {
        'gym' => 'Member',
        'shop' => 'Customer',
        'other' => 'Person',
        _ => 'Student',
      };

  String personWordPlural() => switch (centreType) {
        'gym' => tr('members'),
        'shop' => tr('customers'),
        'other' => tr('people'),
        _ => tr('students'),
      };

  String groupWord() => switch (centreType) {
        'gym' => 'Plan',
        'shop' => 'Item',
        'other' => 'Group',
        _ => 'Batch',
      };

  String feeWord() => switch (centreType) {
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
    notes.remove(id);
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

  List<Map<String, String>> notesFor(String studentId) =>
      notes[studentId] ?? <Map<String, String>>[];

  void addNote(String studentId, String text) {
    final list = notes.putIfAbsent(studentId, () => <Map<String, String>>[]);
    list.insert(0, {'date': stampDate(DateTime.now()), 'text': text});
    save();
  }

  void removeNote(String studentId, int index) {
    final list = notes[studentId];
    if (list != null && index >= 0 && index < list.length) {
      list.removeAt(index);
      save();
    }
  }

  void addBill(Map<String, dynamic> bill) {
    bills.insert(0, bill);
    save();
  }

  void removeBill(String id) {
    bills.removeWhere((b) => b['id'] == id);
    save();
  }
}
