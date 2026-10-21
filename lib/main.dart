import 'package:flutter/material.dart';

void main() {
  runApp(const MySaathiApp());
}

class MySaathiApp extends StatelessWidget {
  const MySaathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySaathi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F4E79),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _centre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  void _login() {
    final centre =
        _centre.text.trim().isEmpty ? 'My Centre' : _centre.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeScreen(centreName: centre)),
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
              const SizedBox(height: 40),
              const Icon(Icons.school, size: 72, color: Color(0xFF1F4E79)),
              const SizedBox(height: 12),
              const Text(
                'MySaathi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F4E79),
                ),
              ),
              const Text(
                'Manage your centre - students, attendance and fees',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _centre,
                decoration: const InputDecoration(
                  labelText: 'Centre Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _login,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Login / Create Account',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Step 1 preview build - login connects to Firebase in the next step.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.centreName});

  final String centreName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MySaathi'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Welcome, $centreName',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('App is working. Features come next.'),
          ],
        ),
      ),
    );
  }
}
