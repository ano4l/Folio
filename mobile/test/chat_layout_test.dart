import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio_mobile/screens/ask_ai_screen.dart';
import 'package:folio_mobile/screens/documents_screen.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/theme/app_theme.dart';
import 'package:folio_mobile/widgets/ai_content.dart';
import 'reliability_test.dart' as fixtures;

void main() {
  for (final width in [320.0, 412.0, 900.0]) {
    testWidgets('document chat fits ${width}px with keyboard and large text', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 850);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = fixtures.stateFor(
        fixtures.FakeApi(),
        fixtures.MemoryStore(),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.5),
                    viewInsets: const EdgeInsets.only(bottom: 280),
                  ),
                  child: child!,
                ),
            home: const DocumentChatPage(document: fixtures.doc),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My saved question');
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.draftFor(fixtures.doc.id), 'My saved question');
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Send question'), findsOneWidget);
    });
  }

  testWidgets('summary renders Markdown without raw headings or bold markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiContent(
            text:
                '## Requirements\n\n**Renewal** is due.\n\n- Submit proof\n- Keep a copy',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upload sheet scrolls above keyboard on a narrow phone', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = fixtures.stateFor(fixtures.FakeApi(), fixtures.MemoryStore());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: const EdgeInsets.only(bottom: 260)),
                child: child!,
              ),
          home: const DocumentsScreen(),
        ),
      ),
    );
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Scan pages with camera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
