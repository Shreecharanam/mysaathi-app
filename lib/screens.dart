import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';

const MethodChannel _launcher = MethodChannel('mysaathi/launch');

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
    _toast(context, 'Pehle Settings mein apni UPI ID daalein');
    return;
  }
  final url = 'upi://pay?pa=${Uri.encodeComponent(upiId)}'
      '&pn=${Uri.encodeComponent(name)}'
      '&am=${amount.toStringAsFixed(2)}&cu=INR';
  final ok = await openUrl(url);
  if (!ok) {
    _toast(context, 'Koi UPI app nahi mila');
  }
}

Future<void> sendWhatsApp(
    BuildContext context, String phone, String message) async {
  final n = waNumber(phone);
  if (n.isEmpty) {
    _toast(context, 'Is vyakti ka phone number nahi hai');
    return;
  }
  final url = 'https://wa.me/$n?text=${Uri.encodeComponent(message)}';
  final ok = await openUrl(url);
  if (!ok) {
    _toast(context, 'WhatsApp nahi khul paya');
  }
}

class LoginScreen extends StatefulWidget {
  final AppStore store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _centre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _type = 'tuition';

  @override
  void initState() {
    super.initState();
    _centre.text = widget.store.centreName;
    _type = widget.store.centreType;
  }

  void _login() {
    final name = _centre.text.trim().isEmpty ? 'My Centre' : _centre.text.trim();
    widget.store.login(name, _type);
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.school, size: 72, color: Color(0xFF1F4E79)),
              const SizedBox(height: 12),
              const Text('MySaathi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              const Text('Manage your centre - people, attendance and fees',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text('Version $appVersion',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
              AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  final err = widget.store.storageError;
                  if (err == null) {
                    return const SizedBox(height: 0);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Storage problem: $err',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.red)),
                  );
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _centre,
                decoration: const InputDecoration(
                    labelText: 'Centre Name',
                    helperText: 'Each centre name keeps its own separate data',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                    labelText: 'Business Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category)),
                items: const [
                  DropdownMenuItem(
                      value: 'tuition', child: Text('Tuition / Coaching')),
                  DropdownMenuItem(value: 'gym', child: Text('Gym / Fitness')),
                  DropdownMenuItem(
                      value: 'clinic', child: Text('Clinic / Doctor')),
                  DropdownMenuItem(value: 'shop', child: Text('Shop / Store')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'tuition'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _login,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Login / Create Account',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              const Text(
                  'Step 9 build - clinic ke liye Description tab (per patient record).',
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
  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController upi;
  late final TextEditingController phone;

  @override
  void initState() {
    super.initState();
    upi = TextEditingController(text: widget.store.upiId);
    phone = TextEditingController(text: widget.store.centrePhone);
  }

  @override
  void dispose() {
    upi.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: upi,
              decoration: const InputDecoration(
                  labelText: 'UPI ID (e.g. yourname@upi)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Centre WhatsApp Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.chat)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                widget.store.setPayments(upi.text.trim(), phone.text.trim());
                _toast(context, 'Saved');
              },
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Save'),
            ),
            const SizedBox(height: 16),
            const Text(
                'Note: "Pay via UPI" opens the student UPI app with the amount filled. '
                'Automatic payment confirmation needs a payment gateway. '
                '"Send WhatsApp" opens WhatsApp with the message ready - you just tap send.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

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

  Future<void> _switchAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch account?'),
        content:
            const Text('This returns to the login screen. Your data is saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch')),
        ],
      ),
    );
    if (ok == true) {
      widget.store.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final clinic = store.isClinic;
    final pages = <Widget>[
      StudentsTab(store: store),
      clinic ? NotesTab(store: store) : AttendanceTab(store: store),
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
            title: const Text('Exit MySaathi?'),
            content: const Text('Do you want to close the app?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Exit')),
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
          backgroundColor: const Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: store)));
              },
            ),
            IconButton(
              icon: const Icon(Icons.switch_account),
              tooltip: 'Switch account',
              onPressed: _switchAccount,
            ),
          ],
        ),
        body: pages[_index],
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                onPressed: _addStudent, child: const Icon(Icons.add))
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.people),
                label: store.personWordPlural()),
            NavigationDestination(
                icon: Icon(clinic ? Icons.edit_note : Icons.check_circle),
                label: clinic ? 'Description' : 'Attendance'),
            const NavigationDestination(
                icon: Icon(Icons.currency_rupee), label: 'Fees'),
          ],
        ),
      ),
    );
  }
}

class AddPersonDialog extends StatefulWidget {
  final AppStore store;
  const AddPersonDialog({super.key, required this.store});

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
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: batch,
                decoration: InputDecoration(labelText: store.groupWord())),
            TextField(
                controller: fee,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: store.feeWord())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: period,
              decoration: const InputDecoration(labelText: 'Fee Period'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                DropdownMenuItem(
                    value: 'half', child: Text('Half-Yearly (twice a year)')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                DropdownMenuItem(value: 'once', child: Text('One-time')),
              ],
              onChanged: (v) => setState(() => period = v ?? 'monthly'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Join Date: ${fmtDate(join)}')),
                TextButton.icon(
                  onPressed: _pickJoinDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Pick'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class StudentsTab extends StatelessWidget {
  final AppStore store;
  const StudentsTab({super.key, required this.store});

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
                  '${s.batch}   -   Rs ${s.fee.toStringAsFixed(0)} ${periodLabel(s.feePeriod)}   -   Joined ${s.joinDate}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => store.removeStudent(s.id),
              ),
            );
          },
        );
      },
    );
  }
}

class NotesTab extends StatelessWidget {
  final AppStore store;
  const NotesTab({super.key, required this.store});

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
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Har patient ka apna alag record - kisi ka ek jagah nahi.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: store.students.length,
                itemBuilder: (context, i) {
                  final s = store.students[i];
                  final list = store.notesFor(s.id);
                  return ListTile(
                    leading: CircleAvatar(
                      child:
                          Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase()),
                    ),
                    title: Text(s.name),
                    subtitle: Text(list.isEmpty
                        ? 'No description yet - tap to add'
                        : (list.first['text'] ?? '')),
                    isThreeLine: false,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (list.isNotEmpty)
                          Text('${list.length}',
                              style: const TextStyle(color: Colors.black45)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_note),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => PatientNotesDialog(
                            store: store, personId: s.id, personName: s.name),
                      );
                    },
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

class PatientNotesDialog extends StatefulWidget {
  final AppStore store;
  final String personId;
  final String personName;
  const PatientNotesDialog(
      {super.key,
      required this.store,
      required this.personId,
      required this.personName});

  @override
  State<PatientNotesDialog> createState() => _PatientNotesDialogState();
}

class _PatientNotesDialogState extends State<PatientNotesDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final list = widget.store.notesFor(widget.personId);
        return AlertDialog(
          title: Text(widget.personName),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _text,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'New description / note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      final t = _text.text.trim();
                      if (t.isEmpty) {
                        return;
                      }
                      widget.store.addNote(widget.personId, t);
                      _text.clear();
                    },
                    child: const Text('Add'),
                  ),
                ),
                const Divider(),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No description yet.',
                        style: TextStyle(color: Colors.black54)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final n = list[i];
                        return ListTile(
                          dense: true,
                          title: Text(n['text'] ?? ''),
                          subtitle: Text(n['date'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () =>
                                widget.store.removeNote(widget.personId, i),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      },
    );
  }
}

class AttendanceTab extends StatefulWidget {
  final AppStore store;
  const AttendanceTab({super.key, required this.store});

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Date: ${fmtDate(date)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Pick date'),
                  ),
                ],
              ),
            ),
            if (store.students.isEmpty)
              const Expanded(
                  child: Center(child: Text('Add people first.')))
            else ...[
              Text(
                  'Present: ${store.students.where((s) => store.isPresent(key, s.id)).length} / ${store.students.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
  const FeesTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.students.isEmpty) {
          return const Center(child: Text('Add people first.'));
        }
        return ListView.builder(
          itemCount: store.students.length,
          itemBuilder: (context, i) {
            final s = store.students[i];
            final pk = periodKeyFor(DateTime.now(), s.feePeriod);
            final paid = store.paidFor(s.id, pk);
            final due = s.fee - paid;
            final pendingMsg = 'Namaste ${s.name}, ${store.centreName} ki fees '
                'Rs ${due.toStringAsFixed(0)} pending hai. Kripya UPI se pay karein.'
                '${store.upiId.isEmpty ? '' : ' UPI ID: ${store.upiId}'} Dhanyavaad.';
            final paidMsg = 'Namaste ${s.name}, ${store.centreName} ko '
                'Rs ${paid.toStringAsFixed(0)} fees mil gayi. Dhanyavaad!';
            return ListTile(
              title: Text(s.name),
              subtitle: Text(
                  '${periodLabel(s.feePeriod)}: Rs ${s.fee.toStringAsFixed(0)}   -   Paid Rs ${paid.toStringAsFixed(0)}   -   ${due <= 0 ? 'Paid' : 'Due Rs ${due.toStringAsFixed(0)}'}'),
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
                    const PopupMenuItem(
                        value: 'upi', child: Text('Pay via UPI')),
                  const PopupMenuItem(
                      value: 'wa', child: Text('Send WhatsApp')),
                  if (due > 0)
                    const PopupMenuItem(
                        value: 'paid', child: Text('Mark as paid')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
