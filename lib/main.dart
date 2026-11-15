import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import 'main_screen.dart';
import 'services/app_services.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Buka SharedPreferences sekali; seluruh request & cache memakai instance ini.
  await ApiClient.init();
  final prefs = await appPrefs();
  final String? token = prefs.getString('auth_token');

  final Widget initialScreen = (token != null && token.isNotEmpty)
      ? const MainScreen() // Token ada -> langsung masuk aplikasi
      : const LoginScreen(); // Token tidak ada -> harus login dulu

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Learning Gamification',
      debugShowCheckedModeBanner: false,
      // PENTING: tanpa ini forceLogout() tidak bisa pindah ke halaman login.
      navigatorKey: appNavigatorKey,
      theme: AppTheme.theme,
      home: initialScreen,
    );
  }
}
