import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:yapyap2/screens/login_screen.dart';
import 'package:yapyap2/screens/signup_screen.dart';
import 'package:yapyap2/screens/home_screen.dart';
import 'firebase_options.dart'; // Ensure you have this file from `flutterfire configure`

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check if the user is already logged in
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(initialRoute: isLoggedIn ? '/home' : '/login'));
}

class MyApp extends StatelessWidget {
  final String initialRoute; // Add initialRoute parameter

  const MyApp({Key? key, required this.initialRoute}) : super(key: key); // Update constructor

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
      primary: Colors.teal, // Explicitly set primary, or let fromSeed derive it
      secondary: Colors.tealAccent, // Explicitly set secondary, or let fromSeed derive it
      // For dark themes, fromSeed will generate appropriate surface, background, onPrimary, onSecondary etc.
    );

    final m3DarkTypography = Typography.material2021(
      platform: Theme.of(context).platform,
      colorScheme: darkColorScheme,
    );
    return MaterialApp(
      title: 'YapYap',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkColorScheme,
        // Use M3 typography. .white provides text colors suitable for a dark background.
        textTheme: m3DarkTypography.white.copyWith(
        ),
        scaffoldBackgroundColor: darkColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.surface,
          elevation: 0,
          titleTextStyle: m3DarkTypography.white.headlineSmall?.copyWith(color: darkColorScheme.onSurface),
          iconTheme: IconThemeData(color: darkColorScheme.onSurface),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkColorScheme.surfaceContainerHighest, // A common M3 choice for filled fields
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          labelStyle: TextStyle(color: darkColorScheme.onSurfaceVariant),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkColorScheme.primary,
            foregroundColor: darkColorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            // The textStyle here primarily affects font properties like size, weight. Color is from foregroundColor.
            // This specific TextStyle is generally fine and unlikely to be the sole cause.
            textStyle: m3DarkTypography.white.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkColorScheme.secondary, // Or primary, depending on desired emphasis
          ),
        ),
      ),
      initialRoute: initialRoute, // Use the initialRoute parameter
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
