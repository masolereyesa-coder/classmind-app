import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/subject_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/note_screen.dart';
import 'screens/qa_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const ClassMindApp());
}

class ClassMindApp extends StatelessWidget {
  const ClassMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (ctx) => const SplashScreen(),
        '/login': (ctx) => const LoginScreen(),
        '/register': (ctx) => const RegisterScreen(),
        '/home': (ctx) => const HomeScreen(),
        '/settings': (ctx) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/subject') {
          return MaterialPageRoute(
            builder: (ctx) => SubjectScreen(
              subject: settings.arguments as dynamic,
            ),
          );
        }
        if (settings.name == '/upload') {
          return MaterialPageRoute(
            builder: (ctx) => UploadScreen(
              preselectedSubject: settings.arguments as dynamic,
            ),
          );
        }
        if (settings.name == '/note') {
          return MaterialPageRoute(
            builder: (ctx) => NoteScreen(
              note: settings.arguments as dynamic,
            ),
          );
        }
        if (settings.name == '/qa') {
          return MaterialPageRoute(
            builder: (ctx) => QAScreen(
              subject: settings.arguments as dynamic,
            ),
          );
        }
        return null;
      },
    );
  }
}
