import 'package:flutter/cupertino.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'firebase_options.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Plant Monitoring',
      theme: const CupertinoThemeData(
        primaryColor: Color(0xFF34C759),
        brightness: Brightness.light,
        scaffoldBackgroundColor: Color(0xFFF2F2F7),
        textTheme: CupertinoTextThemeData(textStyle: TextStyle(fontSize: 17)),
      ),
      home: const HomeScreen(),
    );
  }
}
