import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/hub_state.dart';
import 'ui/setup_screen.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HubState()),
      ],
      child: const RedleafHubApp(),
    ),
  );
}

class RedleafHubApp extends StatelessWidget {
  const RedleafHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Redleaf Hub',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Deep black background
        cardColor: const Color(0xFF1E1E24), // Dark charcoal for panels/rectangles
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA22323), // Redleaf Cool Red
          secondary: Color(0xFF4fc1ff), // Link Blue from Node Leaf
          surface: Color(0xFF2A2A32), // Lighter grey for hover states
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w300, fontSize: 32, color: Colors.white),
          titleMedium: TextStyle(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFE8E8EA)), // Text light
          bodySmall: TextStyle(color: Color(0xFF828290)), // Text muted
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA22323),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      home: const AuthRouter(),
    );
  }
}

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final hubState = context.watch<HubState>();

    // Show nothing while loading SharedPreferences
    if (hubState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFA22323))),
      );
    }

    // If they haven't set their Home Directory or Node Leaf executable yet, show Setup
    if (!hubState.isSetupComplete) {
      return const SetupScreen();
    }

    // Otherwise, show the main project library
    return const HomeScreen();
  }
}