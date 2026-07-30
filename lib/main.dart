import 'package:flutter/cupertino.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
// import 'firebase_options.dart';
import 'screens/root_shell.dart';
import 'theme/app_colors.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Hold the native splash screen until startup work below is done.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());

  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Plant Monitoring',
      theme: const CupertinoThemeData(
        primaryColor: AppColors.green,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontSize: 17,
          ),
        ),
      ),
      home: const RootShell(),
    );
  }
}
