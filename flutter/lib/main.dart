import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/conversations_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite for desktop platforms (not for web or mobile)
  if (!kIsWeb) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      print('Database initialization: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Wait for theme to initialize
          if (!themeProvider.isInitialized) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return MaterialApp(
            title: 'E2EE Chat',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: const LoginScreen(),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/login':
                  return MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  );
                case '/conversations':
                  return MaterialPageRoute(
                    builder: (context) => const ConversationsScreen(),
                  );
                case '/profile':
                  return MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  );
                case '/admin':
                  return MaterialPageRoute(
                    builder: (context) => const AdminDashboardScreen(),
                  );
                case '/settings':
                  return MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  );
                case '/chat':
                  final args = settings.arguments;
                  if (args is Map<String, dynamic>) {
                    return MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        userId: args['userId'] as String,
                        username: args['username'] as String,
                      ),
                    );
                  }
                  break;
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
