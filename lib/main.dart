import 'package:flutter/material.dart';
import 'store.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  runApp(MySaathiApp(store: store));
  store.load();
}

class MySaathiApp extends StatelessWidget {
  final AppStore store;
  const MySaathiApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySaathi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F4E79),
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.accountKey.isEmpty) {
            return LoginScreen(store: store);
          }
          return HomeScreen(store: store);
        },
      ),
    );
  }
}
