import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/main.dart';
import 'package:folio_mobile/screens/login_screen.dart';
import 'package:folio_mobile/screens/main_shell.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/theme/app_theme.dart';

void main() {
  testWidgets('Folio app renders login screen', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final state = AppState()..authStep = 'credentials';
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const FolioApp()),
    );
    await tester.pump();
    expect(find.text('Your funding paperwork, finally clear.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('MFA uses the polished secure code input', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final state = AppState()..authStep = 'mfa';
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Secure code'), findsOneWidget);
    expect(find.textContaining('paste all six digits'), findsOneWidget);
  });

  testWidgets('Expanded layouts use a persistent navigation rail', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState()..authStep = 'authenticated';
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: AppTheme.light, home: const MainShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Documents'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Security'), findsOneWidget);
  });
}
