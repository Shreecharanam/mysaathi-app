import 'package:flutter/material.dart';
import 'store.dart';

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

  @override
  void initState() {
    super.initState();
    _centre.text = widget.store.centreName;
  }

  void _login() {
    final name = _centre.text.trim().isEmpty ? 'My Centre' : _centre.text.trim();
    widget.store.setCentre(name);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(store: widget.store)),
    );
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
              const SizedBox(height: 32),
              const Icon(Icons.school, size: 72, color: Color(0xFF1F4E79)),
              const SizedBox(height: 12),
              const Text('MySaathi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              const Text('Manage your centre - students, attendance and fees',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 32),
              TextField(
                controller: _centre,
                decoration: const InputDecoration(
                    labelText: 'Centre Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store)),
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
                  'Step 2 build - your data is saved on this phone. Cloud sync comes next.',
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
    final name = TextEditingController();
    final phone = TextEditingController();
    final batch = TextEditingController();
    final fee = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Student'),
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
                  decoration: const InputDecoration(labelText: 'Batch / Class')),
              TextField(
                  controller: fee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly Fee')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) {
                return;
              }
              widget.store.addStudent(Student(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                phone: phone.text.trim(),
                batch: batch.text.trim(),
                fee: double.tryParse(fee.text.trim()) ?? 0,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pages = <Widget>[
      StudentsTab(store: store),
      AttendanceTab(store: store),
      FeesTab(store: store),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(store.centreName.isEmpty ? 'MySaathi' : store.centreName),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: pages[_index],
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: _addStudent, child: const Icon(Icons.add))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Students'),
          NavigationDestination(
              icon: Icon(Icons.check_circle), label: 'Attendance'),
          NavigationDestination(
              icon: Icon(Icons.currency_rupee), label: 'Fees'),
        ],
      ),
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
          return const Center(child: Text('No students yet. Tap + to add one.'));
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
                  '\${s.batch}   -   Rs \${s.fee.toStringAsFixed(0)}/month'),
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

class AttendanceTab extends StatelessWidget {
  final AppStore store;
  const AttendanceTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final date = store.todayKey(DateTime.now());
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.students.isEmpty) {
          return const Center(child: Text('Add students first.'));
        }
        final present =
            store.students.where((s) => store.isPresent(date, s.id)).length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  'Today: \$present / \${store.students.length} present',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: store.students.length,
                itemBuilder: (context, i) {
                  final s = store.students[i];
                  return CheckboxListTile(
                    value: store.isPresent(date, s.id),
                    onChanged: (_) => store.toggleAttendance(date, s.id),
                    title: Text(s.name),
                    subtitle: Text(s.batch),
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

class FeesTab extends StatelessWidget {
  final AppStore store;
  const FeesTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final month = store.monthKey(DateTime.now());
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.students.isEmpty) {
          return const Center(child: Text('Add students first.'));
        }
        return ListView.builder(
          itemCount: store.students.length,
          itemBuilder: (context, i) {
            final s = store.students[i];
            final paid = store.paidFor(s.id, month);
            final due = s.fee - paid;
            return ListTile(
              title: Text(s.name),
              subtitle: Text(
                  'Fee Rs \${s.fee.toStringAsFixed(0)}   -   Paid Rs \${paid.toStringAsFixed(0)}'),
              trailing: due <= 0
                  ? const Chip(label: Text('Paid'))
                  : TextButton(
                      onPressed: () => store.setPaid(s.id, month, s.fee),
                      child: Text('Rs \${due.toStringAsFixed(0)} due'),
                    ),
            );
          },
        );
      },
    );
  }
}
