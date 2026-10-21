import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                  'Step 6 build - separate data per centre, fee period, back button fixed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
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
    final pages = <Widget>[
      StudentsTab(store: store),
      AttendanceTab(store: store),
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
            const NavigationDestination(
                icon: Icon(Icons.check_circle), label: 'Attendance'),
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
            return ListTile(
              title: Text(s.name),
              subtitle: Text(
                  '${periodLabel(s.feePeriod)}: Rs ${s.fee.toStringAsFixed(0)}   -   Paid Rs ${paid.toStringAsFixed(0)}'),
              trailing: due <= 0
                  ? const Chip(label: Text('Paid'))
                  : TextButton(
                      onPressed: () => store.setPaid(s.id, pk, s.fee),
                      child: Text('Rs ${due.toStringAsFixed(0)} due'),
                    ),
            );
          },
        );
      },
    );
  }
}
