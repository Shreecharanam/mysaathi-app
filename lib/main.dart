import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'store.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  runApp(MySaathiApp(store: store));
  store.load();
  initFirebase(store);
}

Future<void> initFirebase(AppStore store) async {
  try {
    await Firebase.initializeApp();
    store.firebaseReady = true;
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      store.sessionUid = u.uid;
      await store.load();
    }
  } catch (e) {
    store.firebaseError = e.toString();
  }
  store.refresh();
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
          if (!store.loggedIn) {
            return LoginScreen(store: store);
          }
          if (!store.centreOpen) {
            return CentreChooserScreen(store: store);
          }
          return HomeScreen(store: store);
        },
      ),
    );
  }
}
