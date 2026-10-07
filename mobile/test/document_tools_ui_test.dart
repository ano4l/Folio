import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/screens/documents_screen.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/theme/app_theme.dart';

import 'reliability_test.dart' as fixtures;

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('iOS vault exposes native document tools', (tester) async {
    final state = fixtures.stateFor(fixtures.FakeApi(), fixtures.MemoryStore());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
          home: const DocumentsScreen(),
        ),
      ),
    );
    expect(find.text('Document tools'), findsOneWidget);
    await tester.tap(find.text('Document tools'));
    await tester.pumpAndSettle();
    expect(find.text('Scan pages'), findsOneWidget);
    expect(find.text('Combine PDFs'), findsOneWidget);
    expect(find.text('Images to PDF'), findsOneWidget);
    expect(find.text('Extract PDF pages'), findsOneWidget);
    expect(find.text('Word to PDF'), findsOneWidget);
  });

  testWidgets('Android vault keeps its existing upload flow', (tester) async {
    final state = fixtures.stateFor(fixtures.FakeApi(), fixtures.MemoryStore());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
          home: const DocumentsScreen(),
        ),
      ),
    );
    expect(find.text('Document tools'), findsNothing);
    expect(find.text('Upload'), findsOneWidget);
  });
}
