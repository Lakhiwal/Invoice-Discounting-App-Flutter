import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_discounting_app/screens/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegisterScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      // Verify screen renders
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('shows Create Account heading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Create account.'), findsOneWidget);
    });

    testWidgets('shows only Investor and Partner user types', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      // Should find Investor and Partner
      expect(find.text('Investor'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);

      // Should NOT find Seller or Debtor
      expect(find.text('Seller'), findsNothing);
      expect(find.text('Debtor'), findsNothing);
    });

    testWidgets('shows user type descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Invest in invoices'), findsOneWidget);
      expect(find.text('Business collaboration'), findsOneWidget);
    });

    testWidgets('shows all required form fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('PAN number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
    });

    testWidgets('shows Create Account button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows sign in link', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
