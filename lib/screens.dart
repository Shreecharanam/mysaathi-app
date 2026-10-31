import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'store.dart';
import 'lang.dart';
import 'theme.dart';

MethodChannel _launcher = MethodChannel('mysaathi/launch');

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseStamp(String s) {
  final p = s.split('-');
  if (p.length == 3) {
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d != null && m != null && y != null) {
      return DateTime(y, m, d);
    }
  }
  return null;
}

String waNumber(String raw) {
  var d = raw.replaceAll(RegExp('[^0-9]'), '');
  if (d.length == 10) {
    d = '91' + d;
  }
  return d;
}

Future<bool> openUrl(String url) async {
  try {
    final ok = await _launcher.invokeMethod<bool>('openUrl', {'url': url});
    return ok ?? false;
  } catch (e) {
    return false;
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> payUpi(
  BuildContext context,
  String upiId,
  String name,
  double amount,
) async {
  if (upiId.trim().isEmpty) {
    _toast(context, tr('err_set_upi'));
    return;
  }
  final url =
      'upi://pay?pa=${Uri.encodeComponent(upiId)}'
      '&pn=${Uri.encodeComponent(name)}'
      '&am=${amount.toStringAsFixed(2)}&cu=INR';
  final ok = await openUrl(url);
  if (!ok) {
    _toast(context, tr('err_no_upi_app'));
  }
}

Future<void> sendWhatsApp(
  BuildContext context,
  String phone,
  String message,
) async {
  final n = waNumber(phone);
  if (n.isEmpty) {
    _toast(context, tr('err_no_phone'));
    return;
  }
  final url = 'https://wa.me/$n?text=${Uri.encodeComponent(message)}';
  final ok = await openUrl(url);
  if (!ok) {
    _toast(context, tr('err_no_whatsapp'));
  }
}

/// Plain-text report for one student, shared with the parent.
String studentReport(AppStore store, Student s) {
  final now = DateTime.now();
  final pk = periodKeyFor(now, s.feePeriod);
  final paid = store.paidFor(s.id, pk);
  final due = s.fee - paid;
  final dates = store.attendance.keys.toList();
  final presentDays = dates.where((d) => store.isPresent(d, s.id)).length;
  final total = dates.length;
  final pct = total == 0 ? 0 : (presentDays * 100 / total).round();
  final b = StringBuffer();
  b.writeln(store.centreName);
  b.writeln('Student: ${s.name}');
  if (s.className.isNotEmpty) b.writeln('Class: ${s.className}');
  if (s.batch.isNotEmpty) b.writeln('${store.groupWord()}: ${s.batch}');
  b.writeln('');
  b.writeln('Attendance: $presentDays/$total days ($pct%)');
  b.writeln('');
  b.writeln(
    'Fees (${periodLabel(s.feePeriod)}): Rs ${s.fee.toStringAsFixed(0)}',
  );
  b.writeln('Paid: Rs ${paid.toStringAsFixed(0)}');
  b.writeln('Pending: Rs ${due > 0 ? due.toStringAsFixed(0) : '0'}');
  final tests = store.tests
      .where((t) => t.batch.isEmpty || t.batch == s.batch)
      .toList();
  if (tests.isNotEmpty) {
    b.writeln('');
    b.writeln('Test marks:');
    for (final t in tests) {
      final m = store.markFor(t.id, s.id);
      b.writeln(
        '  ${t.name}: ${m.toStringAsFixed(0)}/${t.maxMarks.toStringAsFixed(0)}',
      );
    }
  }
  return b.toString();
}

/// Dialog to enter an activation code after payment.
Future<void> showActivateDialog(BuildContext context, AppStore store) async {
  final c = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Activate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store.licenceLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the activation code you received after payment.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'MS-20271012-1234'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            final ok = store.applyCode(c.text);
            Navigator.pop(ctx);
            _toast(context, ok ? 'Activated' : 'Invalid code');
          },
          child: const Text('Activate'),
        ),
      ],
    ),
  );
}

class _ItemRow {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController();
  final gst = TextEditingController(text: '0');
  double get qtyV => double.tryParse(qty.text.trim()) ?? 0;
  double get rateV => double.tryParse(rate.text.trim()) ?? 0;
  double get gstV => double.tryParse(gst.text.trim()) ?? 0;
  double get lineTotal => qtyV * rateV;
  double get lineGst => lineTotal * gstV / 100;
  void dispose() {
    name.dispose();
    qty.dispose();
    rate.dispose();
    gst.dispose();
  }
}

class LoginScreen extends StatefulWidget {
  final AppStore store;
  LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _centre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _type = 'tuition';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _centre.text = widget.store.centreName;
    final t = widget.store.centreType;
    _type = (t == 'clinic') ? 'tuition' : t;
  }

  String get _name =>
      _centre.text.trim().isEmpty ? 'My Centre' : _centre.text.trim();

  Future<void> _google() async {
    final store = widget.store;
    if (!store.firebaseReady) {
      _toast(context, tr('cloud_not_ready'));
      return;
    }
    setState(() => _busy = true);
    try {
      final gs = GoogleSignIn();
      try {
        await gs.signOut();
      } catch (_) {}
      final account = await gs.signIn();
      if (account == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final auth = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final uc = await FirebaseAuth.instance.signInWithCredential(cred);
      await store.loginWithUid(uc.user!.uid, _name, _type);
    } catch (e) {
      if (mounted) _toast(context, '${tr('err_google')}: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _create() async {
    final store = widget.store;
    if (!store.firebaseReady) {
      await store.loginLocal(_name, _type);
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      _toast(context, tr('err_email_pw'));
      return;
    }
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await store.loginWithUid(cred.user!.uid, _name, _type);
    } catch (e) {
      if (mounted) _toast(context, '${tr('err_account')}: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _login() async {
    final store = widget.store;
    if (!store.firebaseReady) {
      await store.loginLocal(_name, _type);
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _toast(context, tr('err_email_pass2'));
      return;
    }
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await store.loginWithUid(cred.user!.uid, _name, _type);
    } catch (e) {
      if (mounted) _toast(context, '${tr('err_login')}: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _centre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16),
              Icon(Icons.school, size: 64, color: AppTint.brand(context)),
              SizedBox(height: 10),
              Text(
                'MySaathi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTint.brand(context),
                ),
              ),
              Text(
                tr('tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTint.muted(context)),
              ),
              SizedBox(height: 4),
              Text(
                '${tr('version')} $appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTint.faint(context)),
              ),
              AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  final store = widget.store;
                  final err =
                      store.firebaseError ??
                      store.cloudError ??
                      store.storageError;
                  if (err != null) {
                    return Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '${tr('problem')}: $err',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTint.danger(context),
                        ),
                      ),
                    );
                  }
                  final String msg;
                  if (!store.firebaseReady) {
                    msg = tr('cloud_connecting');
                  } else if (store.cloudStatus == 'saved') {
                    msg = tr('cloud_saved');
                  } else if (store.cloudStatus == 'restored') {
                    msg = tr('cloud_restored');
                  } else {
                    msg = tr('cloud_connected');
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTint.faint(context),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: _centre,
                decoration: InputDecoration(
                  labelText: tr('centre_name'),
                  helperText: tr('centre_name_help'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                  labelText: tr('business_type'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'tuition',
                    child: Text(tr('type_tuition')),
                  ),
                  DropdownMenuItem(value: 'gym', child: Text(tr('type_gym'))),
                  DropdownMenuItem(value: 'shop', child: Text(tr('type_shop'))),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text(tr('type_other')),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'tuition'),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: Icon(Icons.account_circle),
                label: Text(tr('signin_google')),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              SizedBox(height: 10),
              Text(
                tr('or_email'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTint.faint(context)),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: tr('email'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr('password'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _login,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(tr('login')),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(tr('create_account')),
                    ),
                  ),
                ],
              ),
              if (_busy)
                Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Center(child: CircularProgressIndicator()),
                ),
              SizedBox(height: 12),
              Text(
                tr('first_time_help'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTint.faint(context)),
              ),
              SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ParentViewScreen()),
                ),
                icon: const Icon(Icons.family_restroom, size: 18),
                label: const Text('Parent? View your child record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final AppStore store;
  SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController upi;
  late final TextEditingController phone;
  late final TextEditingController gst;
  late final TextEditingController addr;

  @override
  void initState() {
    super.initState();
    upi = TextEditingController(text: widget.store.upiId);
    phone = TextEditingController(text: widget.store.centrePhone);
    gst = TextEditingController(text: widget.store.gstin);
    addr = TextEditingController(text: widget.store.shopAddress);
  }

  @override
  void dispose() {
    upi.dispose();
    phone.dispose();
    gst.dispose();
    addr.dispose();
    super.dispose();
  }

  Future<void> _exportCsv(BuildContext context) async {
    final store = widget.store;
    final b = StringBuffer();
    b.writeln('Name,Phone,ParentPhone,Class,Batch,Fee,FeePeriod,JoinDate');
    for (final s in store.students) {
      b.writeln(
        '"${s.name}","${s.phone}","${s.parentPhone}","${s.className}",'
        '"${s.batch}",${s.fee},"${s.feePeriod}","${s.joinDate}"',
      );
    }
    b.writeln('');
    b.writeln('Batch,Subject,Timing,Fee');
    for (final x in store.batches) {
      b.writeln('"${x.name}","${x.subject}","${x.timing}",${x.fee}');
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (context.mounted) {
      _toast(context, tr('u_csv_copied'));
    }
  }

  Future<void> _clearData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_data_q')),
        content: Text(tr('delete_data_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.clearCentreData();
      if (mounted) _toast(context, tr('data_deleted'));
    }
  }

  Future<void> _deleteAccount() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_account_q')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('u_delete_warn')),
            SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(labelText: tr('type_delete')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim().toUpperCase() == 'DELETE'),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
      await widget.store.deleteAccount();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: upi,
              decoration: InputDecoration(
                labelText: tr('upi_id'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            SizedBox(height: 14),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('centre_whatsapp'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat),
              ),
            ),
            SizedBox(height: 14),
            TextField(
              controller: gst,
              decoration: InputDecoration(
                labelText: tr('gstin'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
            SizedBox(height: 14),
            TextField(
              controller: addr,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr('shop_address'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                widget.store.setPayments(
                  upi.text.trim(),
                  phone.text.trim(),
                  gst.text.trim(),
                  addr.text.trim(),
                );
                _toast(context, tr('saved'));
              },
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(tr('save')),
            ),
            SizedBox(height: 28),
            Divider(),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: gLang,
              decoration: InputDecoration(
                labelText: tr('language'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
              ),
              items: [
                for (var i = 0; i < kLangCodes.length; i++)
                  DropdownMenuItem(
                    value: kLangCodes[i],
                    child: Text(kLangNames[i]),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  widget.store.setLang(v);
                }
              },
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => openUrl('https://seekhojeeto.github.io/'),
              icon: Icon(Icons.school_outlined),
              label: Text('Learn - Seekho Jeeto (free)'),
            ),
            SizedBox(height: 20),
            Text('Licence', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(widget.store.licenceLabel),
            SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showActivateDialog(context, widget.store),
              icon: Icon(Icons.vpn_key),
              label: Text('Activate / enter code'),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _exportCsv(context),
              icon: Icon(Icons.download),
              label: Text(tr('u_export_csv')),
            ),
            SizedBox(height: 20),
            Text(
              tr('delete_options'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTint.danger(context),
              ),
            ),
            SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clearData,
              child: Text(tr('delete_centre_data')),
            ),
            SizedBox(height: 8),
            OutlinedButton(
              onPressed: _deleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTint.danger(context),
              ),
              child: Text(tr('delete_account')),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppStore store;
  HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _addStudent() {
    showDialog(
      context: context,
      builder: (_) => AddPersonDialog(store: widget.store),
    );
  }

  void _newBill() {
    showDialog(
      context: context,
      builder: (_) => NewBillDialog(store: widget.store),
    );
  }

  void _addBatch() {
    showDialog(
      context: context,
      builder: (_) => AddBatchDialog(store: widget.store),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('logout_q')),
        content: Text(tr('u_logout_warn')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('logout')),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      await widget.store.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final shop = store.isShop;
    final pages = <Widget>[
      DashboardTab(
        store: store,
        onStudents: () => setState(() => _index = 1),
        onAttendance: shop ? null : () => setState(() => _index = 2),
        onFees: () => setState(() => _index = 3),
        onBatches: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => BatchesScreen(store: store))),
      ),
      StudentsTab(store: store),
      shop ? BillsTab(store: store) : AttendanceTab(store: store),
      FeesTab(store: store),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('exit_q')),
            content: Text(tr('exit_body')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('exit')),
              ),
            ],
          ),
        );
        if (exit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(store.centreName.isEmpty ? 'MySaathi' : store.centreName),
          actions: [
            if (!shop)
              IconButton(
                icon: Icon(Icons.groups),
                tooltip: store.groupWordPlural(),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BatchesScreen(store: store),
                    ),
                  );
                },
              ),
            if (!shop)
              IconButton(
                icon: Icon(Icons.assignment),
                tooltip: tr('u_tests'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TestsScreen(store: store),
                    ),
                  );
                },
              ),
            IconButton(
              icon: Icon(Icons.swap_horiz),
              tooltip: tr('switch_centre'),
              onPressed: () {
                widget.store.openChooser();
              },
            ),
            IconButton(
              icon: Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: store),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.logout),
              tooltip: tr('logout'),
              onPressed: _logout,
            ),
          ],
        ),
        body: Column(
          children: [
            if (!store.licenceActive)
              Container(
                width: double.infinity,
                color: const Color(0xFF7A1F1F),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Trial over. Activate to add new data.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showActivateDialog(context, store),
                      child: const Text(
                        'Activate',
                        style: TextStyle(
                          color: AppColors.goldSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: pages[_index]),
          ],
        ),
        floatingActionButton: !store.licenceActive
            ? FloatingActionButton(
                onPressed: () => showActivateDialog(context, store),
                child: const Icon(Icons.lock_outline),
              )
            : (_index == 1
                  ? FloatingActionButton(
                      onPressed: _addStudent,
                      child: const Icon(Icons.add),
                    )
                  : (shop && _index == 2
                        ? FloatingActionButton(
                            onPressed: _newBill,
                            child: const Icon(Icons.add),
                          )
                        : null)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: tr('u_home'),
            ),
            NavigationDestination(
              icon: Icon(Icons.people),
              label: store.personWordPlural(),
            ),
            NavigationDestination(
              icon: Icon(shop ? Icons.receipt_long : Icons.check_circle),
              label: shop ? tr('billing') : tr('attendance'),
            ),
            NavigationDestination(
              icon: Icon(Icons.currency_rupee),
              label: tr('fees'),
            ),
          ],
        ),
      ),
    );
  }
}

class NewBillDialog extends StatefulWidget {
  final AppStore store;
  NewBillDialog({super.key, required this.store});

  @override
  State<NewBillDialog> createState() => _NewBillDialogState();
}

class _NewBillDialogState extends State<NewBillDialog> {
  final cust = TextEditingController();
  final custPhone = TextEditingController();
  final rows = <_ItemRow>[_ItemRow()];

  @override
  void dispose() {
    cust.dispose();
    custPhone.dispose();
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get subtotal => rows.fold(0.0, (a, r) => a + r.lineTotal);
  double get gstTotal => rows.fold(0.0, (a, r) => a + r.lineGst);
  double get total => subtotal + gstTotal;

  void _save() {
    final items = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (r.name.text.trim().isEmpty) {
        continue;
      }
      items.add({
        'name': r.name.text.trim(),
        'qty': r.qtyV,
        'rate': r.rateV,
        'gst': r.gstV,
      });
    }
    if (items.isEmpty) {
      _toast(context, tr('err_min_item'));
      return;
    }
    widget.store.addBill({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'customer': cust.text.trim().isEmpty ? 'Customer' : cust.text.trim(),
      'phone': custPhone.text.trim(),
      'date': fmtDate(DateTime.now()),
      'items': items,
      'subtotal': subtotal,
      'gst': gstTotal,
      'total': total,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('new_bill')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: cust,
                decoration: InputDecoration(labelText: tr('customer_name')),
              ),
              TextField(
                controller: custPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('customer_phone')),
              ),
              SizedBox(height: 12),
              Text(tr('item'), style: TextStyle(fontWeight: FontWeight.bold)),
              for (var i = 0; i < rows.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: rows[i].name,
                        decoration: InputDecoration(labelText: tr('item')),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: rows[i].qty,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: tr('qty')),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: rows[i].rate,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: tr('rate')),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: rows[i].gst,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: tr('gst_percent'),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: rows.length == 1
                          ? null
                          : () {
                              setState(() {
                                rows.removeAt(i).dispose();
                              });
                            },
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => rows.add(_ItemRow())),
                  icon: Icon(Icons.add),
                  label: Text(tr('add_item')),
                ),
              ),
              Divider(),
              Text('Subtotal: Rs ${subtotal.toStringAsFixed(2)}'),
              Text('GST: Rs ${gstTotal.toStringAsFixed(2)}'),
              Text(
                'Total: Rs ${total.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(tr('save_bill'))),
      ],
    );
  }
}

class BillsTab extends StatelessWidget {
  final AppStore store;
  BillsTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.bills.isEmpty) {
          return Center(child: Text(tr('no_bills')));
        }
        return ListView.builder(
          itemCount: store.bills.length,
          itemBuilder: (context, i) {
            final b = store.bills[i];
            final custName = (b['customer'] ?? '') as String;
            final date = (b['date'] ?? '') as String;
            final tot = ((b['total'] ?? 0) as num).toDouble();
            return ListTile(
              leading: CircleAvatar(child: Icon(Icons.receipt_long)),
              title: Text(custName),
              subtitle: Text('$date   -   Rs ${tot.toStringAsFixed(2)}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'wa') {
                    final items = (b['items'] ?? []) as List;
                    final buf = StringBuffer();
                    buf.writeln('*${store.centreName}*');
                    if (store.shopAddress.isNotEmpty) {
                      buf.writeln(store.shopAddress);
                    }
                    if (store.gstin.isNotEmpty) {
                      buf.writeln('GSTIN: ${store.gstin}');
                    }
                    buf.writeln('---');
                    buf.writeln('Customer: $custName');
                    buf.writeln('Date: $date');
                    buf.writeln('---');
                    for (final it in items) {
                      final m = it as Map;
                      buf.writeln(
                        '${m['name']}  x${m['qty']}  @${m['rate']}  GST ${m['gst']}%',
                      );
                    }
                    buf.writeln('---');
                    buf.writeln(
                      'Subtotal: Rs ${((b['subtotal'] ?? 0) as num).toStringAsFixed(2)}',
                    );
                    buf.writeln(
                      'GST: Rs ${((b['gst'] ?? 0) as num).toStringAsFixed(2)}',
                    );
                    buf.writeln('*Total: Rs ${tot.toStringAsFixed(2)}*');
                    sendWhatsApp(
                      context,
                      (b['phone'] ?? '') as String,
                      buf.toString(),
                    );
                  } else if (v == 'del') {
                    store.removeBill((b['id'] ?? '') as String);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'wa', child: Text(tr('send_bill_wa'))),
                  PopupMenuItem(value: 'del', child: Text(tr('delete'))),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AddPersonDialog extends StatefulWidget {
  final AppStore store;
  final Student? edit;
  AddPersonDialog({super.key, required this.store, this.edit});

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final parent = TextEditingController();
  final klass = TextEditingController();
  final fee = TextEditingController();
  DateTime join = DateTime.now();
  String period = 'monthly';
  String batchSel = '';

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      name.text = e.name;
      phone.text = e.phone;
      parent.text = e.parentPhone;
      klass.text = e.className;
      fee.text = e.fee > 0 ? e.fee.toStringAsFixed(0) : '';
      period = e.feePeriod;
      batchSel = e.batch;
      join = parseStamp(e.joinDate) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    parent.dispose();
    klass.dispose();
    fee.dispose();
    super.dispose();
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: join,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => join = picked);
    }
  }

  List<String> _batchOptions(AppStore store) {
    final names = <String>{};
    for (final b in store.batches) {
      if (b.name.trim().isNotEmpty) names.add(b.name.trim());
    }
    if (batchSel.trim().isNotEmpty) names.add(batchSel.trim());
    return <String>['', ...names.toList()];
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AlertDialog(
      title: Text(
        widget.edit == null
            ? 'Add ${store.personWord()}'
            : 'Edit ${store.personWord()}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: tr('u_name')),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('u_phone')),
            ),
            TextField(
              controller: parent,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('u_parent_phone')),
            ),
            TextField(
              controller: klass,
              decoration: InputDecoration(labelText: tr('u_class')),
            ),
            DropdownButtonFormField<String>(
              value: batchSel,
              decoration: InputDecoration(labelText: store.groupWord()),
              items: _batchOptions(store)
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.isEmpty ? tr('u_none') : b),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => batchSel = v ?? ''),
            ),
            TextField(
              controller: fee,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: store.feeWord()),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: period,
              decoration: InputDecoration(labelText: tr('fee_period')),
              items: [
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text(tr('p_monthly')),
                ),
                DropdownMenuItem(
                  value: 'quarterly',
                  child: Text(tr('p_quarterly')),
                ),
                DropdownMenuItem(value: 'half', child: Text(tr('p_half'))),
                DropdownMenuItem(value: 'yearly', child: Text(tr('p_yearly'))),
                DropdownMenuItem(value: 'once', child: Text(tr('p_once'))),
              ],
              onChanged: (v) => setState(() => period = v ?? 'monthly'),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Join Date: ${fmtDate(join)}')),
                TextButton.icon(
                  onPressed: _pickJoinDate,
                  icon: Icon(Icons.calendar_month),
                  label: Text(tr('pick')),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) {
              return;
            }
            final s = Student(
              id:
                  widget.edit?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              name: name.text.trim(),
              phone: phone.text.trim(),
              parentPhone: parent.text.trim(),
              className: klass.text.trim(),
              batch: batchSel,
              fee: double.tryParse(fee.text.trim()) ?? 0,
              joinDate: fmtDate(join),
              feePeriod: period,
            );
            if (widget.edit == null) {
              store.addStudent(s);
            } else {
              store.updateStudent(s);
            }
            Navigator.pop(context);
          },
          child: Text(widget.edit == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class StudentsTab extends StatefulWidget {
  final AppStore store;
  StudentsTab({super.key, required this.store});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  String batchFilter = '';
  String query = '';

  Future<void> _shareReport(
    BuildContext context,
    AppStore store,
    Student s,
  ) async {
    final text = studentReport(store, s);
    final phone = s.parentPhone.isNotEmpty ? s.parentPhone : s.phone;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Send on WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                sendWhatsApp(context, phone, text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy report'),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: text));
                _toast(context, tr('u_csv_copied'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Parent access code'),
              subtitle: const Text(
                'Parent can see this record live (read only)',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _accessCode(context, store, s);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accessCode(
    BuildContext context,
    AppStore store,
    Student s,
  ) async {
    final code = await store.ensureAccessCode(s);
    if (!context.mounted) return;
    final phone = s.parentPhone.isNotEmpty ? s.parentPhone : s.phone;
    final msg =
        'Namaste,\n'
        '${store.centreName}\n\n'
        'You can now see the record of ${s.name} in the MySaathi app.\n'
        'Access code: $code\n\n'
        'Open the app, tap Parent view, and enter this code.';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parent access code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this code with the parent:'),
            const SizedBox(height: 10),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The parent can see attendance, fees and marks - read only.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              store.clearAccessCode(s);
              Navigator.pop(ctx);
            },
            child: const Text('Turn off'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Clipboard.setData(ClipboardData(text: code));
              _toast(context, tr('u_csv_copied'));
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              sendWhatsApp(context, phone, msg);
            },
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final batches = <String>{''};
        for (final s in store.students) {
          if (s.batch.trim().isNotEmpty) batches.add(s.batch.trim());
        }
        final byBatch = batchFilter.isEmpty
            ? store.students
            : store.students.where((s) => s.batch == batchFilter).toList();
        final q = query.trim().toLowerCase();
        final list = q.isEmpty
            ? byBatch
            : byBatch
                  .where(
                    (s) =>
                        s.name.toLowerCase().contains(q) ||
                        s.phone.contains(q) ||
                        s.className.toLowerCase().contains(q),
                  )
                  .toList();
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: tr('u_search_hint'),
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: batches.contains(batchFilter) ? batchFilter : '',
                      decoration: InputDecoration(
                        labelText: store.groupWord(),
                        isDense: true,
                      ),
                      items: batches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text(b.isEmpty ? tr('u_all') : b),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => batchFilter = v ?? ''),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '${list.length}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        'No ${store.personWordPlural().toLowerCase()} yet. Tap + to add one.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final s = list[i];
                        final parts = <String>[];
                        if (s.className.isNotEmpty)
                          parts.add('Class ${s.className}');
                        if (s.batch.isNotEmpty) parts.add(s.batch);
                        parts.add(
                          'Rs ${s.fee.toStringAsFixed(0)} ${periodLabel(s.feePeriod)}',
                        );
                        if (s.parentPhone.isNotEmpty) {
                          parts.add('P: ${s.parentPhone}');
                        }
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                            ),
                          ),
                          title: Text(s.name),
                          subtitle: Text(parts.join('  •  ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.share_outlined),
                                tooltip: 'Share report',
                                onPressed: () =>
                                    _shareReport(context, store, s),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined),
                                tooltip: tr('u_edit'),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) =>
                                      AddPersonDialog(store: store, edit: s),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline),
                                onPressed: () => store.removeStudent(s.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class AttendanceTab extends StatefulWidget {
  final AppStore store;
  AttendanceTab({super.key, required this.store});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  DateTime date = DateTime.now();
  String batchFilter = '';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final key = isoDate(date);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final batches = <String>{''};
        for (final s in store.students) {
          if (s.batch.trim().isNotEmpty) batches.add(s.batch.trim());
        }
        final shown = batchFilter.isEmpty
            ? store.students
            : store.students.where((s) => s.batch == batchFilter).toList();
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${fmtDate(date)}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: Icon(Icons.calendar_month),
                    label: Text(tr('pick_date')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonFormField<String>(
                value: batches.contains(batchFilter) ? batchFilter : '',
                decoration: InputDecoration(
                  labelText: store.groupWord(),
                  isDense: true,
                ),
                items: batches
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.isEmpty ? tr('u_all') : b),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => batchFilter = v ?? ''),
              ),
            ),
            if (store.students.isEmpty)
              Expanded(child: Center(child: Text(tr('add_people_first'))))
            else ...[
              Padding(
                padding: EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Present: ${shown.where((s) => store.isPresent(key, s.id)).length} / ${shown.length}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final s = shown[i];
                    return CheckboxListTile(
                      value: store.isPresent(key, s.id),
                      onChanged: (_) => store.toggleAttendance(key, s.id),
                      title: Text(s.name),
                      subtitle: Text(s.batch),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class FeesTab extends StatefulWidget {
  final AppStore store;
  FeesTab({super.key, required this.store});

  @override
  State<FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<FeesTab> {
  bool onlyDue = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.students.isEmpty) {
          return Center(child: Text(tr('add_people_first')));
        }
        final now = DateTime.now();
        double totalDue = 0;
        int dueCount = 0;
        for (final s in store.students) {
          final pk = periodKeyFor(now, s.feePeriod);
          final due = s.fee - store.paidFor(s.id, pk);
          if (due > 0) {
            totalDue += due;
            dueCount++;
          }
        }
        final list = onlyDue
            ? store.students.where((s) {
                final pk = periodKeyFor(now, s.feePeriod);
                return (s.fee - store.paidFor(s.id, pk)) > 0;
              }).toList()
            : store.students;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Due: Rs ${totalDue.toStringAsFixed(0)}  ($dueCount)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTint.danger(context),
                      ),
                    ),
                  ),
                  FilterChip(
                    label: Text(tr('u_only_due')),
                    selected: onlyDue,
                    onSelected: (v) => setState(() => onlyDue = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(tr('u_all_paid')))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final s = list[i];
                        final pk = periodKeyFor(DateTime.now(), s.feePeriod);
                        final paid = store.paidFor(s.id, pk);
                        final due = s.fee - paid;
                        final pendingMsg =
                            'Hello ${s.name}, your fees of '
                            'Rs ${due.toStringAsFixed(0)} at ${store.centreName} are pending. '
                            'Please pay by UPI.'
                            '${store.upiId.isEmpty ? '' : ' UPI ID: ${store.upiId}'} Thank you.';
                        final paidMsg =
                            'Hello ${s.name}, ${store.centreName} has received '
                            'Rs ${paid.toStringAsFixed(0)}. Thank you!';
                        return ListTile(
                          title: Text(s.name),
                          subtitle: Text(
                            '${periodLabel(s.feePeriod)}: Rs ${s.fee.toStringAsFixed(0)}   -   Paid Rs ${paid.toStringAsFixed(0)}   -   ${due <= 0 ? tr('paid') : 'Due Rs ${due.toStringAsFixed(0)}'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'upi') {
                                payUpi(
                                  context,
                                  store.upiId,
                                  store.centreName,
                                  due,
                                );
                              } else if (v == 'wa') {
                                sendWhatsApp(
                                  context,
                                  s.phone,
                                  due > 0 ? pendingMsg : paidMsg,
                                );
                              } else if (v == 'paid') {
                                store.setPaid(s.id, pk, s.fee);
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (due > 0)
                                PopupMenuItem(
                                  value: 'upi',
                                  child: Text(tr('pay_upi')),
                                ),
                              PopupMenuItem(
                                value: 'wa',
                                child: Text(tr('send_whatsapp')),
                              ),
                              if (due > 0)
                                PopupMenuItem(
                                  value: 'paid',
                                  child: Text(tr('mark_paid')),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class BatchesTab extends StatelessWidget {
  final AppStore store;
  BatchesTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.batches.isEmpty) {
          return Center(
            child: Text(
              'No ${store.groupWordPlural().toLowerCase()} yet. Tap + to add one.',
            ),
          );
        }
        return ListView.builder(
          itemCount: store.batches.length,
          itemBuilder: (context, i) {
            final b = store.batches[i];
            final count = store.students.where((s) => s.batch == b.name).length;
            final bits = <String>[];
            if (b.subject.isNotEmpty) bits.add(b.subject);
            if (b.timing.isNotEmpty) bits.add(b.timing);
            bits.add('Rs ${b.fee.toStringAsFixed(0)}');
            bits.add('$count ${store.personWordPlural().toLowerCase()}');
            return ListTile(
              leading: CircleAvatar(child: Icon(Icons.groups)),
              title: Text(b.name),
              subtitle: Text(bits.join('  •  ')),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: () => store.removeBatch(b.id),
              ),
            );
          },
        );
      },
    );
  }
}

class AddBatchDialog extends StatefulWidget {
  final AppStore store;
  AddBatchDialog({super.key, required this.store});

  @override
  State<AddBatchDialog> createState() => _AddBatchDialogState();
}

class _AddBatchDialogState extends State<AddBatchDialog> {
  final name = TextEditingController();
  final subject = TextEditingController();
  final timing = TextEditingController();
  final fee = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    subject.dispose();
    timing.dispose();
    fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AlertDialog(
      title: Text('Add ${store.groupWord()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: '${store.groupWord()} name (e.g. Class 10 Maths)',
              ),
            ),
            TextField(
              controller: subject,
              decoration: InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: timing,
              decoration: InputDecoration(labelText: 'Timing (e.g. 5-6 PM)'),
            ),
            TextField(
              controller: fee,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: store.feeWord()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            store.addBatch(
              Batch(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                subject: subject.text.trim(),
                timing: timing.text.trim(),
                fee: double.tryParse(fee.text.trim()) ?? 0,
              ),
            );
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}

class DashboardTab extends StatelessWidget {
  final AppStore store;
  final VoidCallback? onStudents;
  final VoidCallback? onAttendance;
  final VoidCallback? onFees;
  final VoidCallback? onBatches;

  DashboardTab({
    super.key,
    required this.store,
    this.onStudents,
    this.onAttendance,
    this.onFees,
    this.onBatches,
  });

  Widget _stat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final body = Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTint.subtle(context)),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final todayKey = isoDate(now);
        final present = store.students
            .where((s) => store.isPresent(todayKey, s.id))
            .length;
        double expected = 0;
        double collected = 0;
        for (final s in store.students) {
          final pk = periodKeyFor(now, s.feePeriod);
          expected += s.fee;
          collected += store.paidFor(s.id, pk);
        }
        final due = expected - collected;
        return ListView(
          padding: EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  child: _stat(
                    context,
                    '${store.students.length}',
                    store.personWordPlural(),
                    Icons.people,
                    Colors.blue,
                    onTap: onStudents,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    context,
                    '$present/${store.students.length}',
                    tr('u_present_today'),
                    Icons.check_circle,
                    Colors.green,
                    onTap: onAttendance,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    context,
                    'Rs ${collected.toStringAsFixed(0)}',
                    tr('u_collected'),
                    Icons.currency_rupee,
                    Colors.teal,
                    onTap: onFees,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    context,
                    'Rs ${due.toStringAsFixed(0)}',
                    tr('u_due'),
                    Icons.warning_amber,
                    AppTint.danger(context),
                    onTap: onFees,
                  ),
                ),
              ],
            ),
            if (!store.isShop) ...[
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      context,
                      '${store.batches.length}',
                      store.groupWordPlural(),
                      Icons.groups,
                      Colors.indigo,
                      onTap: onBatches,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: SizedBox()),
                ],
              ),
            ],
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReportsScreen(store: store)),
              ),
              icon: Icon(Icons.bar_chart),
              label: Text(tr('u_view_reports')),
            ),
          ],
        );
      },
    );
  }
}

class ReportsScreen extends StatelessWidget {
  final AppStore store;
  ReportsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('u_reports'))),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final now = DateTime.now();
          final dates = store.attendance.keys.toList();
          final totalDays = dates.length;
          double expected = 0;
          double collected = 0;
          for (final s in store.students) {
            final pk = periodKeyFor(now, s.feePeriod);
            expected += s.fee;
            collected += store.paidFor(s.id, pk);
          }
          return ListView(
            padding: EdgeInsets.all(12),
            children: [
              Text(
                tr('u_fees'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Expected: Rs ${expected.toStringAsFixed(0)}    '
                'Collected: Rs ${collected.toStringAsFixed(0)}    '
                'Due: Rs ${(expected - collected).toStringAsFixed(0)}',
              ),
              Divider(height: 24),
              Text(
                'Attendance (days recorded: $totalDays)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              if (store.students.isEmpty)
                Text(tr('u_no_data'))
              else
                for (final s in store.students)
                  Builder(
                    builder: (context) {
                      final presentDays = dates
                          .where((d) => store.isPresent(d, s.id))
                          .length;
                      final pct = totalDays == 0
                          ? 0
                          : (presentDays * 100 / totalDays).round();
                      return ListTile(
                        dense: true,
                        title: Text(s.name),
                        subtitle: Text(s.batch),
                        trailing: Text('$presentDays/$totalDays ($pct%)'),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class BatchesScreen extends StatelessWidget {
  final AppStore store;
  BatchesScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(store.groupWordPlural())),
      body: BatchesTab(store: store),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => AddBatchDialog(store: store),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}

class TestsScreen extends StatelessWidget {
  final AppStore store;
  TestsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('u_tests'))),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.tests.isEmpty) {
            return Center(child: Text(tr('u_no_tests')));
          }
          return ListView.builder(
            itemCount: store.tests.length,
            itemBuilder: (context, i) {
              final t = store.tests[i];
              final bits = <String>[];
              if (t.batch.isNotEmpty) bits.add(t.batch);
              if (t.date.isNotEmpty) bits.add(t.date);
              bits.add('Max ${t.maxMarks.toStringAsFixed(0)}');
              return ListTile(
                leading: CircleAvatar(child: Icon(Icons.assignment)),
                title: Text(t.name),
                subtitle: Text(bits.join('  •  ')),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MarkEntryScreen(store: store, test: t),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline),
                  onPressed: () => store.removeTest(t.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => AddTestDialog(store: store),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddTestDialog extends StatefulWidget {
  final AppStore store;
  AddTestDialog({super.key, required this.store});

  @override
  State<AddTestDialog> createState() => _AddTestDialogState();
}

class _AddTestDialogState extends State<AddTestDialog> {
  final name = TextEditingController();
  final maxMarks = TextEditingController(text: '100');
  String batchSel = '';

  @override
  void dispose() {
    name.dispose();
    maxMarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final batches = <String>{''};
    for (final b in store.batches) {
      if (b.name.trim().isNotEmpty) batches.add(b.name.trim());
    }
    return AlertDialog(
      title: Text(tr('u_add_test')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: tr('u_test_name')),
            ),
            DropdownButtonFormField<String>(
              value: batchSel,
              decoration: InputDecoration(labelText: store.groupWord()),
              items: batches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.isEmpty ? tr('u_all') : b),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => batchSel = v ?? ''),
            ),
            TextField(
              controller: maxMarks,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('u_max_marks')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            store.addTest(
              Test(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                batch: batchSel,
                date: fmtDate(DateTime.now()),
                maxMarks: double.tryParse(maxMarks.text.trim()) ?? 100,
              ),
            );
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}

class MarkEntryScreen extends StatefulWidget {
  final AppStore store;
  final Test test;
  MarkEntryScreen({super.key, required this.store, required this.test});

  @override
  State<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<MarkEntryScreen> {
  final Map<String, TextEditingController> ctrls = {};
  final List<Student> people = [];

  @override
  void initState() {
    super.initState();
    for (final s in widget.store.students) {
      if (widget.test.batch.isNotEmpty && s.batch != widget.test.batch) {
        continue;
      }
      people.add(s);
      final m = widget.store.markFor(widget.test.id, s.id);
      ctrls[s.id] = TextEditingController(
        text: m > 0 ? m.toStringAsFixed(0) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: Text(widget.test.name)),
      body: people.isEmpty
          ? Center(child: Text(tr('u_no_students_batch')))
          : ListView(
              padding: EdgeInsets.all(12),
              children: [
                for (final s in people)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.name)),
                        SizedBox(
                          width: 124,
                          child: TextField(
                            controller: ctrls[s.id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '0',
                              suffixText:
                                  '/ ${widget.test.maxMarks.toStringAsFixed(0)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          for (final s in people) {
            final v = double.tryParse(ctrls[s.id]!.text.trim()) ?? 0;
            store.setMark(widget.test.id, s.id, v);
          }
          Navigator.pop(context);
        },
        icon: Icon(Icons.save),
        label: Text(tr('u_save')),
      ),
    );
  }
}

class ParentViewScreen extends StatefulWidget {
  const ParentViewScreen({super.key});

  @override
  State<ParentViewScreen> createState() => _ParentViewScreenState();
}

class _ParentViewScreenState extends State<ParentViewScreen> {
  final code = TextEditingController();
  bool loading = false;
  String? error;
  Map<String, dynamic>? data;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  String _n(Object? v) {
    if (v is num) return v.toStringAsFixed(0);
    final p = num.tryParse('$v');
    return p == null ? '$v' : p.toStringAsFixed(0);
  }

  Future<void> _lookup() async {
    final c = code.text.trim().toUpperCase();
    if (c.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      data = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('public_students')
          .doc(c)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() => data = doc.data());
      } else {
        setState(() => error = 'Code not found. Please check and try again.');
      }
    } catch (e) {
      setState(
        () => error = 'Could not load. Please check your internet connection.',
      );
    }
    if (mounted) setState(() => loading = false);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final testList = (d?['tests'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('My child')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          const Text(
            'Enter the access code given by your centre.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'ABCD2345',
              prefixIcon: Icon(Icons.key),
            ),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: loading ? null : _lookup,
            child: Text(loading ? 'Loading...' : 'View record'),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(error!, style: TextStyle(color: AppTint.danger(context))),
          ],
          if (d != null) ...[
            const SizedBox(height: AppSpace.xl),
            Text(
              (d['name'] ?? '').toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpace.sm),
            _row('Centre', (d['centre'] ?? '').toString()),
            if ((d['className'] ?? '').toString().isNotEmpty)
              _row('Class', d['className'].toString()),
            if ((d['batch'] ?? '').toString().isNotEmpty)
              _row(
                (d['groupWord'] ?? 'Batch').toString(),
                d['batch'].toString(),
              ),
            const Divider(height: 26),
            const Text(
              'Attendance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _row(
              'Present',
              '${d['present']}/${d['total']} days (${d['pct']}%)',
            ),
            const Divider(height: 26),
            const Text('Fees', style: TextStyle(fontWeight: FontWeight.bold)),
            _row('Plan', (d['feePeriod'] ?? '').toString()),
            _row('Total', 'Rs ${_n(d['fee'])}'),
            _row('Paid', 'Rs ${_n(d['paid'])}'),
            _row('Pending', 'Rs ${_n(d['due'])}'),
            if (testList.isNotEmpty) ...[
              const Divider(height: 26),
              const Text(
                'Test marks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final t in testList)
                _row(
                  (t['name'] ?? '').toString(),
                  '${_n(t['marks'])}/${_n(t['max'])}',
                ),
            ],
            const SizedBox(height: AppSpace.lg),
            Text(
              'Updated: ${(d['updated'] ?? '').toString().replaceFirst('T', ' ').split('.').first}',
              style: TextStyle(fontSize: 11, color: AppTint.faint(context)),
            ),
          ],
        ],
      ),
    );
  }
}

class CentreChooserScreen extends StatelessWidget {
  final AppStore store;
  const CentreChooserScreen({super.key, required this.store});

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await store.logout();
  }

  Future<void> _add(BuildContext context) async {
    if (store.accounts.isNotEmpty) {
      _toast(
        context,
        'One account can have only one centre. Use another Gmail ID for a second centre.',
      );
      return;
    }
    final name = TextEditingController();
    String type = 'tuition';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(tr('new_centre')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: tr('centre_name')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(
                  labelText: tr('business_type'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'tuition',
                    child: Text(tr('type_tuition')),
                  ),
                  DropdownMenuItem(value: 'gym', child: Text(tr('type_gym'))),
                  DropdownMenuItem(value: 'shop', child: Text(tr('type_shop'))),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text(tr('type_other')),
                  ),
                ],
                onChanged: (v) => setSt(() => type = v ?? 'tuition'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('add_centre')),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await store.createCentre(name.text.trim(), type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final ids = store.centreIds();
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('your_centres')),
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: tr('logout'),
                onPressed: () => _logout(context),
              ),
            ],
          ),
          body: ids.isEmpty
              ? Center(child: Text(tr('no_centres')))
              : ListView.builder(
                  itemCount: ids.length,
                  itemBuilder: (context, i) {
                    final cid = ids[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(_typeIcon(store.centreTypeOf(cid))),
                      ),
                      title: Text(store.centreLabel(cid)),
                      subtitle: Text(_typeName(store.centreTypeOf(cid))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => store.removeCentre(cid),
                      ),
                      onTap: () => store.switchTo(cid),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: Text(tr('new_centre')),
          ),
        );
      },
    );
  }
}

IconData _typeIcon(String t) => switch (t) {
  'gym' => Icons.fitness_center,
  'shop' => Icons.storefront,
  'other' => Icons.category,
  _ => Icons.school,
};

String _typeName(String t) => switch (t) {
  'gym' => tr('type_gym'),
  'shop' => tr('type_shop'),
  'other' => tr('type_other'),
  _ => tr('type_tuition'),
};
