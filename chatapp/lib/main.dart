import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'services/firebase_test.dart';

final Logger _logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with better error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.i('✅ Firebase initialized successfully');

    // Test Firebase connectivity first
    final firebaseTest = FirebaseConnectivityTest();
    final isConnected = await firebaseTest.testFirebaseInitialization();

    if (isConnected) {
      _logger.i('✅ Firebase connection verified');

      // NOTE: Sample data will be created after user signs in
      // to ensure proper authentication context
      _logger.i('📝 Sample data will be created after user authentication');
    } else {
      _logger.e('❌ Firebase connection failed - app may not work properly');
    }
  } catch (e) {
    _logger.e('❌ Firebase initialization failed: $e');
    // Continue with app launch even if Firebase fails
  }

  _logger.i('🚀 Real-time chat app starting');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder:
                  (context) => ChatScreen(
                    userId: args['userId'] ?? '',
                    userName: args['userName'] ?? 'Chat',
                  ),
            );
          default:
            return null;
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
