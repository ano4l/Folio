import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:folio_mobile/main.dart';
import 'package:folio_mobile/services/app_state.dart';

void main() {
  testWidgets('Folio app renders login screen', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const FolioApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Welcome to Folio'), findsOneWidget);
  });
}
