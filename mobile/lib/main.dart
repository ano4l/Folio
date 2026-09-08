import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/theme/app_theme.dart';
import 'package:folio_mobile/screens/login_screen.dart';
import 'package:folio_mobile/screens/main_shell.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FolioApp(),
    ),
  );
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Folio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: state.authStep == 'authenticated'
          ? const MainShell()
          : const LoginScreen(),
    );
  }
}
