import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/widgets/folio_motion.dart';
import 'package:folio_mobile/widgets/glass_container.dart';
import 'package:folio_mobile/screens/deadlines_screen.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/theme/app_theme.dart';
import 'reliability_test.dart' as fixtures;

void main() {
  testWidgets('tabs retain input and disable hidden tickers', (tester) async {
    var index = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: FolioTabStack(
                index: index,
                children: const [TextField(), Text('Second page')],
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Retained draft');
    update(() => index = 1);
    await tester.pumpAndSettle();
    final hiddenInput = tester.element(
      find.byType(TextField, skipOffstage: false),
    );
    expect(TickerMode.valuesOf(hiddenInput).enabled, isFalse);
    update(() => index = 0);
    await tester.pumpAndSettle();
    expect(find.text('Retained draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps pressed cards and tab opacity stable', (
    tester,
  ) async {
    var index = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: FolioTabStack(
                  index: index,
                  children: [
                    GlassContainer(onTap: () {}, child: const Text('Press me')),
                    const Text('Next'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Press me')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
    update(() => index = 1);
    await tester.pump();
    final fade =
        find
            .descendant(
              of: find.byType(FolioTabStack),
              matching: find.byType(FadeTransition),
            )
            .first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 412.0, 900.0]) {
    testWidgets('task list and calendar fit $width at large text', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
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
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
            home: const Scaffold(body: DeadlinesScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
