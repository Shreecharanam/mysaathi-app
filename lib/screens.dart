import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'store.dart';
import 'lang.dart';

MethodChannel _launcher = MethodChannel('mysaathi/launch');

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    BuildContext context, String upiId, String name, double amount) async {
  if (upiId.trim().isEmpty) {
    _toast(context, tr('err_set_upi'));
    return;
  }
  final url = 'upi://pay?pa=${Uri.encodeComponent(upiId)}'
      '&pn=${Uri.encodeComponent(name)}'
      '&am=${amount.toStringAsFixed(2)}&cu=INR';
  final ok = await openUrl(url);
  if (!ok) {
    _toast(context, tr('err_no_upi_app'));
  }
}

Future<void> sendWhatsApp(
    BuildContext context, String phone, String message) async {
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
          email: _email.text.trim(), password: _password.text);
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
          email: _email.text.trim(), password: _password.text);
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
              Icon(Icons.school, size: 64, color: Color(0xFF1F4E79)),
              SizedBox(height: 10),
              Text('MySaathi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              Text(tr('tagline'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
              SizedBox(height: 4),
              Text('${tr('version')} $appVersion',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  final store = widget.store;
                  final err = store.firebaseError ??
                      store.cloudError ??
                      store.storageError;
                  if (err != null) {
                    return Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('${tr('problem')}: $err',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11, color: Colors.red)),
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
                    child: Text(msg,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11, color: Colors.black45)),
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
                    prefixIcon: Icon(Icons.store)),
              ),
              SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                    labelText: tr('business_type'),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category)),
                items: [
                  DropdownMenuItem(
                      value: 'tuition', child: Text(tr('type_tuition'))),
                  DropdownMenuItem(value: 'gym', child: Text(tr('type_gym'))),
                  DropdownMenuItem(value: 'shop', child: Text(tr('type_shop'))),
                  DropdownMenuItem(value: 'other', child: Text(tr('type_other'))),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'tuition'),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: Icon(Icons.account_circle),
                label: Text(tr('signin_google')),
                style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16)),
              ),
              SizedBox(height: 10),
              Text(tr('or_email'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: tr('email'),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email)),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: tr('password'),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock)),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _login,
                      style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16)),
                      child: Text(tr('login')),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16)),
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
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
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

  Future<void> _clearData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_data_q')),
        content: Text(
            tr('delete_data_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete'))),
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
            Text(
                'Poora account aur saara data hat jayega. Yeh wapas nahi aayega.'),
            SizedBox(height: 12),
            TextField(
                controller: ctrl,
                decoration: InputDecoration(
                    labelText: tr('type_delete'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrl.text.trim().toUpperCase() == 'DELETE'),
              child: Text(tr('delete'))),
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
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
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
                  prefixIcon: Icon(Icons.qr_code)),
            ),
            SizedBox(height: 14),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: tr('centre_whatsapp'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.chat)),
            ),
            SizedBox(height: 14),
            TextField(
              controller: gst,
              decoration: InputDecoration(
                  labelText: tr('gstin'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long)),
            ),
            SizedBox(height: 14),
            TextField(
              controller: addr,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: tr('shop_address'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on)),
            ),
            SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                widget.store.setPayments(upi.text.trim(), phone.text.trim(),
                    gst.text.trim(), addr.text.trim());
                _toast(context, tr('saved'));
              },
              style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16)),
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
                  prefixIcon: Icon(Icons.language)),
              items: [
                for (var i = 0; i < kLangCodes.length; i++)
                  DropdownMenuItem(
                      value: kLangCodes[i], child: Text(kLangNames[i])),
              ],
              onChanged: (v) {
                if (v != null) {
                  widget.store.setLang(v);
                }
              },
            ),
            SizedBox(height: 20),
            Text(tr('delete_options'),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clearData,
              child: Text(tr('delete_centre_data')),
            ),
            SizedBox(height: 8),
            OutlinedButton(
              onPressed: _deleteAccount,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('logout_q')),
        content:
            Text('Aap login screen par jaayenge. Aapka data safe rahega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('logout'))),
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
                  child: Text(tr('cancel'))),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(tr('exit'))),
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
          backgroundColor: Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          actions: [
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
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: store)));
              },
            ),
            IconButton(
              icon: Icon(Icons.logout),
              tooltip: tr('logout'),
              onPressed: _logout,
            ),
          ],
        ),
        body: pages[_index],
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                onPressed: _addStudent, child: Icon(Icons.add))
            : (shop && _index == 1
                ? FloatingActionButton(
                    onPressed: _newBill, child: Icon(Icons.add))
                : null),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
                icon: Icon(Icons.people),
                label: store.personWordPlural()),
            NavigationDestination(
                icon: Icon(shop ? Icons.receipt_long : Icons.check_circle),
                label: shop ? tr('billing') : tr('attendance')),
            NavigationDestination(
                icon: Icon(Icons.currency_rupee), label: tr('fees')),
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

  double get subtotal =>
      rows.fold(0.0, (a, r) => a + r.lineTotal);
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
                  decoration: InputDecoration(labelText: tr('customer_name'))),
              TextField(
                  controller: custPhone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: tr('customer_phone'))),
              SizedBox(height: 12),
              Text(tr('item'),
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (var i = 0; i < rows.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                          controller: rows[i].name,
                          decoration:
                              InputDecoration(labelText: tr('item'))),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                          controller: rows[i].qty,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              InputDecoration(labelText: tr('qty'))),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                          controller: rows[i].rate,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              InputDecoration(labelText: tr('rate'))),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                          controller: rows[i].gst,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              InputDecoration(labelText: tr('gst_percent'))),
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
              Text('Total: Rs ${total.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel'))),
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
          return Center(
              child: Text(tr('no_bills')));
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
                          '${m['name']}  x${m['qty']}  @${m['rate']}  GST ${m['gst']}%');
                    }
                    buf.writeln('---');
                    buf.writeln(
                        'Subtotal: Rs ${((b['subtotal'] ?? 0) as num).toStringAsFixed(2)}');
                    buf.writeln(
                        'GST: Rs ${((b['gst'] ?? 0) as num).toStringAsFixed(2)}');
                    buf.writeln('*Total: Rs ${tot.toStringAsFixed(2)}*');
                    sendWhatsApp(context, (b['phone'] ?? '') as String,
                        buf.toString());
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
  AddPersonDialog({super.key, required this.store});

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final batch = TextEditingController();
  final fee = TextEditingController();
  DateTime join = DateTime.now();
  String period = 'monthly';

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    batch.dispose();
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

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AlertDialog(
      title: Text('Add ${store.personWord()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: InputDecoration(labelText: 'Name')),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone')),
            TextField(
                controller: batch,
                decoration: InputDecoration(labelText: store.groupWord())),
            TextField(
                controller: fee,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: store.feeWord())),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: period,
              decoration: InputDecoration(labelText: tr('fee_period')),
              items: [
                DropdownMenuItem(value: 'monthly', child: Text(tr('p_monthly'))),
                DropdownMenuItem(value: 'quarterly', child: Text(tr('p_quarterly'))),
                DropdownMenuItem(
                    value: 'half', child: Text(tr('p_half'))),
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
            child: Text(tr('cancel'))),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) {
              return;
            }
            store.addStudent(Student(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name.text.trim(),
              phone: phone.text.trim(),
              batch: batch.text.trim(),
              fee: double.tryParse(fee.text.trim()) ?? 0,
              joinDate: fmtDate(join),
              feePeriod: period,
            ));
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}

class StudentsTab extends StatelessWidget {
  final AppStore store;
  StudentsTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.students.isEmpty) {
          return Center(
              child: Text(
                  'No ${store.personWordPlural().toLowerCase()} yet. Tap + to add one.'));
        }
        return ListView.builder(
          itemCount: store.students.length,
          itemBuilder: (context, i) {
            final s = store.students[i];
            return ListTile(
              leading: CircleAvatar(
                child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase()),
              ),
              title: Text(s.name),
              subtitle: Text(
                  '${s.batch}   -   Rs ${s.fee.toStringAsFixed(0)} ${periodLabel(s.feePeriod)}   -   ${tr('joined')} ${s.joinDate}'),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: () => store.removeStudent(s.id),
              ),
            );
          },
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
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Date: ${fmtDate(date)}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: Icon(Icons.calendar_month),
                    label: Text(tr('pick_date')),
                  ),
                ],
              ),
            ),
            if (store.students.isEmpty)
              Expanded(
                  child: Center(child: Text(tr('add_people_first'))))
            else ...[
              Text(
                  'Present: ${store.students.where((s) => store.isPresent(key, s.id)).length} / ${store.students.length}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: store.students.length,
                  itemBuilder: (context, i) {
                    final s = store.students[i];
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

class FeesTab extends StatelessWidget {
  final AppStore store;
  FeesTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.students.isEmpty) {
          return Center(child: Text(tr('add_people_first')));
        }
        return ListView.builder(
          itemCount: store.students.length,
          itemBuilder: (context, i) {
            final s = store.students[i];
            final pk = periodKeyFor(DateTime.now(), s.feePeriod);
            final paid = store.paidFor(s.id, pk);
            final due = s.fee - paid;
            final pendingMsg = 'Hello ${s.name}, your fees of '
                'Rs ${due.toStringAsFixed(0)} at ${store.centreName} are pending. '
                'Please pay by UPI.'
                '${store.upiId.isEmpty ? '' : ' UPI ID: ${store.upiId}'} Thank you.';
            final paidMsg = 'Hello ${s.name}, ${store.centreName} has received '
                'Rs ${paid.toStringAsFixed(0)}. Thank you!';
            return ListTile(
              title: Text(s.name),
              subtitle: Text(
                  '${periodLabel(s.feePeriod)}: Rs ${s.fee.toStringAsFixed(0)}   -   Paid Rs ${paid.toStringAsFixed(0)}   -   ${due <= 0 ? tr('paid') : 'Due Rs ${due.toStringAsFixed(0)}'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'upi') {
                    payUpi(context, store.upiId, store.centreName, due);
                  } else if (v == 'wa') {
                    sendWhatsApp(
                        context, s.phone, due > 0 ? pendingMsg : paidMsg);
                  } else if (v == 'paid') {
                    store.setPaid(s.id, pk, s.fee);
                  }
                },
                itemBuilder: (ctx) => [
                  if (due > 0)
                    PopupMenuItem(
                        value: 'upi', child: Text(tr('pay_upi'))),
                  PopupMenuItem(
                      value: 'wa', child: Text(tr('send_whatsapp'))),
                  if (due > 0)
                    PopupMenuItem(
                        value: 'paid', child: Text(tr('mark_paid'))),
                ],
              ),
            );
          },
        );
      },
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
                  decoration: InputDecoration(labelText: tr('centre_name'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(
                    labelText: tr('business_type'),
                    border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(
                      value: 'tuition', child: Text(tr('type_tuition'))),
                  DropdownMenuItem(value: 'gym', child: Text(tr('type_gym'))),
                  DropdownMenuItem(value: 'shop', child: Text(tr('type_shop'))),
                  DropdownMenuItem(
                      value: 'other', child: Text(tr('type_other'))),
                ],
                onChanged: (v) => setSt(() => type = v ?? 'tuition'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('add_centre'))),
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
            backgroundColor: const Color(0xFF1F4E79),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: tr('logout'),
                  onPressed: () => _logout(context)),
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
                          child: Icon(_typeIcon(store.centreTypeOf(cid)))),
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
