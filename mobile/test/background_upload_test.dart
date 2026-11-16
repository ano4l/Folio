import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/models/document_upload.dart';
import 'package:folio_mobile/models/document.dart';
import 'package:folio_mobile/screens/documents_screen.dart';
import 'package:folio_mobile/screens/main_shell.dart';
import 'package:folio_mobile/services/api_service.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/services/processing_recovery.dart';
import 'package:folio_mobile/theme/app_theme.dart';
import 'reliability_test.dart' as fixtures;

class UploadApi extends fixtures.FakeApi {
  final upload = Completer<String>();
  ValueChanged<String>? report;
  @override
  Future<String> uploadDocument({
    required String filePath,
    required String title,
    String category = 'Document',
    ValueChanged<String>? onStage,
    ValueChanged<String>? onUploaded,
  }) {
    report = onStage;
    return upload.future;
  }
}

void main() {
  testWidgets(
    'iPhone upload action stays above the dock with safe area and large text',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = fixtures.stateFor(
        fixtures.FakeApi(),
        fixtures.MemoryStore(),
      )..navigationIndex = 1;
      addTearDown(state.dispose);
      for (final scale in [1.0, 1.6]) {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 47, bottom: 34),
                      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
              home: const MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(FloatingActionButton);
        final dock =
            find
                .ancestor(of: find.text('Docs'), matching: find.byType(InkWell))
                .first;
        expect(
          tester.getRect(button).bottom,
          lessThan(tester.getRect(dock).top),
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Secure Paperwork Upload'), findsOneWidget);
        // Dismiss using the route so the next scale verifies the same screen.
        Navigator.of(
          tester.element(find.text('Secure Paperwork Upload')),
        ).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  test('temporary AI failure retries the saved document automatically', () async {
    var requests = 0;
    final paths = <String>[];
    final api = ApiService(
      processingWait: (_) async {},
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body)['documentId'], 'saved-document');
          requests++;
          return http.Response(
            jsonEncode({'status': requests == 1 ? 'REVIEW_REQUIRED' : 'READY'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'documents': [
              {
                'id': 'saved-document',
                'status': 'Needs review',
                'summary':
                    'Text extraction succeeded, but AI summarisation is temporarily unavailable. Retry processing shortly.',
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    expect(await api.processDocumentAutomatically('saved-document'), 'READY');
    expect(requests, 2);
    expect(paths.any((p) => p.contains('upload')), false);
  });

  test(
    'unreadable pages stop for review instead of repeating AI requests',
    () async {
      var requests = 0;
      final result = await recoverDocumentProcessing(
        process: () async {
          requests++;
          return 'REVIEW_REQUIRED';
        },
        inspect:
            () async => const ProcessingSnapshot(
              'Needs review',
              'One or more pages have too little readable text.',
            ),
        ensureCurrent: () {},
        wait: (_) async {},
      );
      expect(result, 'REVIEW_REQUIRED');
      expect(requests, 1);
    },
  );

  test(
    'a request timeout polls existing processing without duplicating work',
    () async {
      var requests = 0;
      var polls = 0;
      final result = await recoverDocumentProcessing(
        process: () async {
          requests++;
          return 'PROCESSING_PENDING';
        },
        inspect:
            () async =>
                ++polls < 3
                    ? const ProcessingSnapshot('Analyzing', '')
                    : const ProcessingSnapshot('Ready', 'Summary'),
        ensureCurrent: () {},
        wait: (_) async {},
      );
      expect(result, 'READY');
      expect(requests, 1);
      expect(polls, 3);
    },
  );

  test('a stale processing lease is recovered automatically', () async {
    var requests = 0;
    final result = await recoverDocumentProcessing(
      process: () async => ++requests == 1 ? 'PROCESSING_PENDING' : 'READY',
      inspect: () async => const ProcessingSnapshot('Analyzing', ''),
      ensureCurrent: () {},
      wait: (_) async {},
    );
    expect(result, 'READY');
    expect(requests, 2);
  });

  test('persistent AI failure ends after three automatic attempts', () async {
    var requests = 0;
    final result = await recoverDocumentProcessing(
      process: () async {
        requests++;
        return 'REVIEW_REQUIRED';
      },
      inspect:
          () async => const ProcessingSnapshot(
            'Needs review',
            'AI summarisation is temporarily unavailable.',
          ),
      ensureCurrent: () {},
      wait: (_) async {},
    );
    expect(result, 'PROCESSING_PENDING');
    expect(requests, 3);
  });

  test(
    'upload stays active across navigation and reports completion',
    () async {
      final api = UploadApi();
      final state = fixtures.stateFor(api, fixtures.MemoryStore());
      addTearDown(state.dispose);
      final pending = state.uploadDocument(
        '/chosen.pdf',
        'Course notes',
        category: 'Lecture Notes',
      );
      state.navigate(2);
      api.report?.call('Reading and summarising…');
      expect(state.navigationIndex, 2);
      expect(state.documentUploads.single.stage, 'Reading and summarising…');
      expect(state.documentUploads.single.isRunning, true);
      api.upload.complete('READY');
      await pending;
      expect(state.documentUploads.single.status, UploadStatus.ready);
      expect(state.navigationIndex, 2);
    },
  );

  test('failed background upload is contained and remains visible', () async {
    final api = UploadApi();
    final state = fixtures.stateFor(api, fixtures.MemoryStore());
    addTearDown(state.dispose);
    state.startDocumentUpload('/chosen.pdf', 'Course notes');
    api.upload.completeError(const ApiException('Storage unavailable', 503));
    await Future<void>.delayed(Duration.zero);
    expect(state.documentUploads.single.status, UploadStatus.failed);
    expect(state.documentUploads.single.stage, 'Storage unavailable');
  });

  test(
    'signing out prevents an old upload from publishing to another account',
    () async {
      final api = UploadApi();
      final state = fixtures.stateFor(api, fixtures.MemoryStore());
      addTearDown(state.dispose);
      final pending = state.uploadDocument('/chosen.pdf', 'Course notes');
      await state.logout();
      state.user = const AuthUser(id: 'bob', email: '', displayName: 'Bob');
      api.report?.call('Old account progress');
      api.upload.complete('READY');
      await pending;
      expect(state.documentUploads, isEmpty);
      expect(state.documents, isEmpty);
      expect(state.auditLogs, isEmpty);
    },
  );

  testWidgets(
    'upload sheet defaults to a general document and offers broad categories',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
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
            home: const DocumentsScreen(),
          ),
        ),
      );
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(field.initialValue, 'Document');
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      final categories = dropdown.items!.map((item) => item.value).toList();
      expect(
        categories,
        containsAll([
          'Lecture Notes',
          'Research & Report',
          'Identity & Personal Record',
          'Employment & Work',
          'Medical & Health',
          'Other',
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
