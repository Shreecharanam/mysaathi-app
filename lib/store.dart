import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'lang.dart';

const String appVersion = 'v25';

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
  String parentPhone;
  String className;
  String batch;
  double fee;
  String joinDate;
  String feePeriod;
  String accessCode;

  Student({
    required this.id,
    required this.name,
    this.phone = '',
    this.parentPhone = '',
    this.className = '',
    this.batch = '',
    this.fee = 0,
    this.joinDate = '',
    this.feePeriod = 'monthly',
    this.accessCode = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'parentPhone': parentPhone,
    'className': className,
    'batch': batch,
    'fee': fee,
    'joinDate': joinDate,
    'feePeriod': feePeriod,
    'accessCode': accessCode,
  };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: (j['phone'] ?? '') as String,
    parentPhone: (j['parentPhone'] ?? '') as String,
    className: (j['className'] ?? '') as String,
    batch: (j['batch'] ?? '') as String,
    fee: ((j['fee'] ?? 0) as num).toDouble(),
    joinDate: (j['joinDate'] ?? '') as String,
    feePeriod: (j['feePeriod'] ?? 'monthly') as String,
    accessCode: (j['accessCode'] ?? '') as String,
  );
}

class Batch {
  String id;
  String name;
  String subject;
  String timing;
  double fee;

  Batch({
    required this.id,
    required this.name,
    this.subject = '',
    this.timing = '',
    this.fee = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subject': subject,
    'timing': timing,
    'fee': fee,
  };
  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    subject: (j['subject'] ?? '') as String,
    timing: (j['timing'] ?? '') as String,
    fee: ((j['fee'] ?? 0) as num).toDouble(),
  );
}

class Test {
  String id;
  String name;
  String batch;
  String date;
  double maxMarks;

  Test({
    required this.id,
    required this.name,
    this.batch = '',
    this.date = '',
    this.maxMarks = 100,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'batch': batch,
    'date': date,
    'maxMarks': maxMarks,
  };

  factory Test.fromJson(Map<String, dynamic> j) => Test(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    batch: (j['batch'] ?? '') as String,
    date: (j['date'] ?? '') as String,
    maxMarks: ((j['maxMarks'] ?? 100) as num).toDouble(),
  );
}

class AppStore extends ChangeNotifier {
  String uid = '';
  String sessionUid = '';
  String accountKey = '';
  String lastCid = '';
  String trialStart = '';
  String paidTill = '';
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
  final List<Batch> batches = [];
  final List<Test> tests = [];
  final Map<String, double> marks = {};
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

  // ---------- licence / trial ----------
  static const int trialDays = 30;

  String get todayIso {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDay(String s) => DateTime.tryParse(s);

  bool get licenceActive {
    final now = DateTime.now();
    final paid = _parseDay(paidTill);
    if (paid != null && now.isBefore(paid.add(const Duration(days: 1)))) {
      return true;
    }
    final t = _parseDay(trialStart);
    if (t == null) return true; // no trial info yet -> fresh trial
    return now.isBefore(t.add(const Duration(days: trialDays)));
  }

  int get trialDaysLeft {
    final t = _parseDay(trialStart);
    if (t == null) return trialDays;
    final left = t
        .add(const Duration(days: trialDays))
        .difference(DateTime.now())
        .inDays;
    return left < 0 ? 0 : left;
  }

  String get licenceLabel {
    final now = DateTime.now();
    final paid = _parseDay(paidTill);
    if (paid != null && now.isBefore(paid.add(const Duration(days: 1)))) {
      return 'Active till ${stampDate(paid)}';
    }
    if (licenceActive) return 'Trial - $trialDaysLeft day(s) left';
    return 'Trial over - activation needed';
  }

  /// Offline activation code: MS-YYYYMMDD-XXXX (XXXX = checksum of date).
  static String codeFor(DateTime d) {
    final ds =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    var h = 0;
    for (final c in (ds + 'MYS8').codeUnits) {
      h = (h * 31 + c) % 10000;
    }
    return 'MS-$ds-${h.toString().padLeft(4, '0')}';
  }

  bool applyCode(String code) {
    final p = code.trim().toUpperCase().split('-');
    if (p.length != 3 || p[0] != 'MS' || p[1].length != 8) return false;
    final ds = p[1];
    final dt = DateTime.tryParse(
      '${ds.substring(0, 4)}-${ds.substring(4, 6)}-${ds.substring(6, 8)}',
    );
    if (dt == null) return false;
    if (p[2] != codeFor(dt).split('-').last) return false;
    paidTill =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    save();
    return true;
  }

  // ---------- parent access codes ----------
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  DateTime? _lastSummaryPush;

  String newAccessCode() {
    final r = Random.secure();
    return List.generate(
      8,
      (_) => _codeChars[r.nextInt(_codeChars.length)],
    ).join();
  }

  Future<String> ensureAccessCode(Student s) async {
    if (s.accessCode.isEmpty) {
      s.accessCode = newAccessCode();
      await save();
    }
    await pushStudentSummary(s);
    return s.accessCode;
  }

  void clearAccessCode(Student s) {
    s.accessCode = '';
    save();
  }

  /// Publishes a read-only summary for the parent (public_students/{code}).
  Future<void> pushStudentSummary(Student s) async {
    if (!firebaseReady || uid.isEmpty || s.accessCode.isEmpty) return;
    final dates = attendance.keys.toList();
    final present = dates.where((d) => isPresent(d, s.id)).length;
    final total = dates.length;
    final pct = total == 0 ? 0 : (present * 100 / total).round();
    final pk = periodKeyFor(DateTime.now(), s.feePeriod);
    final paid = paidFor(s.id, pk);
    final due = s.fee - paid;
    final testRows = <Map<String, dynamic>>[];
    for (final t in tests) {
      if (t.batch.isNotEmpty && t.batch != s.batch) continue;
      testRows.add({
        'name': t.name,
        'marks': markFor(t.id, s.id),
        'max': t.maxMarks,
      });
    }
    try {
      await FirebaseFirestore.instance
          .collection('public_students')
          .doc(s.accessCode)
          .set({
            'ownerUid': uid,
            'centre': centreName,
            'centrePhone': centrePhone,
            'name': s.name,
            'className': s.className,
            'batch': s.batch,
            'groupWord': groupWord(),
            'present': present,
            'total': total,
            'pct': pct,
            'feePeriod': periodLabel(s.feePeriod),
            'fee': s.fee,
            'paid': paid,
            'due': due,
            'tests': testRows,
            'updated': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      cloudError = e.toString();
    }
  }

  Future<void> refreshPublicSummaries() async {
    if (!firebaseReady || uid.isEmpty) return;
    if (!students.any((s) => s.accessCode.isNotEmpty)) return;
    final now = DateTime.now();
    final last = _lastSummaryPush;
    if (last != null && now.difference(last).inSeconds < 60) return;
    _lastSummaryPush = now;
    for (final s in students) {
      if (s.accessCode.isNotEmpty) {
        await pushStudentSummary(s);
      }
    }
  }

  Map<String, dynamic> centreMap() => {
    'centreName': centreName,
    'centreType': centreType,
    'upiId': upiId,
    'centrePhone': centrePhone,
    'gstin': gstin,
    'shopAddress': shopAddress,
    'students': students.map((e) => e.toJson()).toList(),
    'batches': batches.map((e) => e.toJson()).toList(),
    'tests': tests.map((e) => e.toJson()).toList(),
    'marks': marks,
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
    batches.clear();
    tests.clear();
    marks.clear();
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
    for (final e in ((d['batches'] ?? []) as List)) {
      batches.add(Batch.fromJson(Map<String, dynamic>.from(e as Map)));
    }
    for (final e in ((d['tests'] ?? []) as List)) {
      tests.add(Test.fromJson(Map<String, dynamic>.from(e as Map)));
    }
    ((d['marks'] ?? {}) as Map).forEach((k, v) {
      marks[k as String] = (v as num).toDouble();
    });
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
        f.writeAsStringSync(
          jsonEncode({
            'uid': uid,
            'centres': accounts,
            'last': lastCid,
            'trialStart': trialStart,
            'paidTill': paidTill,
          }),
        );
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
              (m['centres'] as Map).forEach(
                (k, v) => accounts[k.toString()] = v,
              );
              _fileUid = fileUid;
              uid = want.isNotEmpty ? want : fileUid;
              lastCid = (m['last'] ?? '').toString();
              trialStart = (m['trialStart'] ?? '').toString();
              paidTill = (m['paidTill'] ?? '').toString();
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
    refreshPublicSummaries();
  }

  Future<void> pushCloud() async {
    if (!firebaseReady || uid.isEmpty) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('centres').doc(uid).set({
        'centres': accounts,
        'last': lastCid,
        'licence': {'trialStart': trialStart, 'paidTill': paidTill},
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
        ((d['centres'] ?? {}) as Map).forEach(
          (k, v) => accounts[k.toString()] = v,
        );
        lastCid = (d['last'] ?? '').toString();
        final lic = d['licence'];
        if (lic is Map) {
          trialStart = (lic['trialStart'] ?? '').toString();
          paidTill = (lic['paidTill'] ?? '').toString();
        }
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
    if (trialStart.isEmpty) trialStart = todayIso;
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
    if (trialStart.isEmpty) trialStart = todayIso;
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
    // One account = one centre (each extra centre needs its own login).
    if (accounts.isNotEmpty) {
      return;
    }
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
    batches.clear();
    tests.clear();
    marks.clear();
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
    batches.clear();
    tests.clear();
    marks.clear();
    attendance.clear();
    payments.clear();
    notes.clear();
    bills.clear();
    await save();
  }

  Future<void> deleteAccount() async {
    accounts.clear();
    students.clear();
    batches.clear();
    tests.clear();
    marks.clear();
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
    batches.clear();
    tests.clear();
    marks.clear();
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

  String groupWordPlural() => switch (centreType) {
    'gym' => 'Plans',
    'shop' => 'Items',
    'other' => 'Groups',
    _ => 'Batches',
  };

  String feeWord() => switch (centreType) {
    'shop' => 'Amount',
    'other' => 'Amount',
    _ => 'Monthly Fee',
  };

  void addBatch(Batch b) {
    batches.add(b);
    save();
  }

  void addTest(Test t) {
    tests.add(t);
    save();
  }

  void removeTest(String id) {
    tests.removeWhere((t) => t.id == id);
    marks.removeWhere((k, v) => k.startsWith('$id|'));
    save();
  }

  double markFor(String testId, String studentId) =>
      marks['$testId|$studentId'] ?? 0;

  void setMark(String testId, String studentId, double value) {
    marks['$testId|$studentId'] = value;
    save();
  }

  void removeBatch(String id) {
    String name = '';
    for (final b in batches) {
      if (b.id == id) name = b.name;
    }
    batches.removeWhere((x) => x.id == id);
    if (name.isNotEmpty) {
      for (final s in students) {
        if (s.batch == name) s.batch = '';
      }
    }
    save();
  }

  void updateStudent(Student s) {
    final i = students.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      students[i] = s;
      save();
    }
  }

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
