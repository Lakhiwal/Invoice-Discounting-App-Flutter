import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_discounting_app/main.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App launches smoke test', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const InvoFinApp(),
      ),
    );

    // Just verify the app renders without crashing
    expect(find.byType(InvoFinApp), findsOneWidget);
  });
}
