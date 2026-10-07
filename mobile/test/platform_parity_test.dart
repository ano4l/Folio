import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/main.dart';
import 'package:folio_mobile/screens/main_shell.dart';
import 'package:folio_mobile/screens/dashboard_screen.dart';
import 'package:folio_mobile/screens/ask_ai_screen.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/services/share_text.dart';
import 'package:folio_mobile/theme/app_theme.dart';
import 'reliability_test.dart' as fixtures;

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Android and iOS retain identical product theme metrics', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = AppTheme.light;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = AppTheme.light;
    debugDefaultTargetPlatformOverride = null;
    expect(ios.platform, TargetPlatform.iOS); // Never spoof native behavior.
    expect(AppColors.teal, const Color(0xFF0E7C74));
    expect(ios.colorScheme, android.colorScheme);
    expect(ios.textTheme, android.textTheme);
    expect(ios.appBarTheme, android.appBarTheme);
    expect(ios.appBarTheme.centerTitle, isFalse);
    expect(ios.splashFactory, android.splashFactory);
    expect(ios.visualDensity, android.visualDensity);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform uses the same green login',
      (tester) async {
        final state = fixtures.stateFor(
          fixtures.FakeApi(),
          fixtures.MemoryStore(),
        )..authStep = 'credentials';
        addTearDown(state.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: const FolioApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Your funding paperwork, finally clear.'),
          findsOneWidget,
        );
        final theme = Theme.of(tester.element(find.text('Sign in')));
        expect(theme.scaffoldBackgroundColor, AppColors.paper);
        expect(
          theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
          AppColors.teal,
        );
        final context = tester.element(find.text('Sign in'));
        final scroll = ScrollConfiguration.of(context);
        expect(scroll.getPlatform(context), TargetPlatform.android);
        expect(scroll.getScrollPhysics(context), isA<ClampingScrollPhysics>());
        expect(theme.platform, platform);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      'same refresh indicator on $platform',
      (tester) async {
        final api = fixtures.FakeApi()..fetch = Completer();
        final state = fixtures.stateFor(api, fixtures.MemoryStore());
        addTearDown(state.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: DashboardScreen()),
            ),
          ),
        );
        final refresh = tester.state<RefreshIndicatorState>(
          find.byType(RefreshIndicator),
        );
        final finished = refresh.show();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        api.fetch!.complete([fixtures.doc]);
        await tester.pumpAndSettle();
        await finished;
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    for (final width in [375.0, 834.0]) {
      testWidgets(
        '$platform shell and document chat fit $width with insets',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final state = fixtures.stateFor(
            fixtures.FakeApi(),
            fixtures.MemoryStore(),
          );
          addTearDown(state.dispose);
          Widget app(
            Widget page, {
            bool keyboard = false,
          }) => ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              theme: AppTheme.light,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 59, bottom: 34),
                      viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                      viewInsets: EdgeInsets.only(bottom: keyboard ? 300 : 0),
                      textScaler: const TextScaler.linear(1.5),
                    ),
                    child: child!,
                  ),
              home: page,
            ),
          );
          await tester.pumpWidget(app(const MainShell()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final index in [1, 2, 3, 4, 0]) {
            state.navigate(index);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(
            app(const DocumentChatPage(document: fixtures.doc), keyboard: true),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField),
            'Keep my document question',
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(state.draftFor(fixtures.doc.id), 'Keep my document question');
          expect(
            tester.getBottomLeft(find.byTooltip('Send question')).dy,
            lessThanOrEqualTo(700),
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }

  testWidgets('sharing supplies an iPad popover origin', (tester) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    MethodCall? received;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      received = call;
      return 'test';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => ShareText.show(context, 'A document answer'),
                  child: const Text('Share'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(received?.method, 'share');
    expect(received?.arguments['text'], 'A document answer');
    expect(received?.arguments['originWidth'], greaterThan(0));
    expect(received?.arguments['originHeight'], greaterThan(0));
  });
}
