import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:test_whisper/home_page.dart";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: "Whisper for Flutter",
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          cardColor: const Color(0xFF16213E),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F3460),
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF16213E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE94560)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ),
        home: const MyHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
