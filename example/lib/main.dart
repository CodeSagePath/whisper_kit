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
              seedColor: Theme.of(context).colorScheme.primary),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
