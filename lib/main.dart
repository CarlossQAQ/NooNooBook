import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/note_provider.dart';
import 'providers/interpretation_provider.dart';
import 'providers/session_provider.dart';
import 'providers/bookshelf_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => BookshelfProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<SessionProvider, InterpretationProvider>(
          create: (_) => InterpretationProvider(),
          update: (_, sessionProv, interpProv) => interpProv!..sessionProvider = sessionProv,
        ),
      ],
      child: const SimulNoteApp(),
    ),
  );
}

class SimulNoteApp extends StatelessWidget {
  const SimulNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final baseTheme = themeProvider.themeData;

    return MaterialApp(
      title: 'SimulNote',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.notoSansScTextTheme(baseTheme.textTheme),
      ),
      home: const DashboardScreen(),
    );
  }
}
