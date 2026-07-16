
import 'package:energy_application/LocalNotificationService.dart';
import 'package:energy_application/NotificationService.dart';
import 'package:energy_application/auth-pages/signin.dart';
import 'package:energy_application/firebaseMDG.dart';
import 'package:energy_application/firebase_options.dart';
import 'package:energy_application/user-pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await LocalNotificationService.init();
  await Firebasemdg().initFCR();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Energy Monitoring Application',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF11221B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF13EC92),
          secondary: Color(0xFF92C9B2),
          surface: Color(0xFF193328),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {

          if (!authSnap.hasData) {
            return Signin();
          }

          if (authSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          return HomePage();
        },
      ),
    );
  }
}
