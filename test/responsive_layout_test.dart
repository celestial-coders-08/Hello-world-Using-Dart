import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/Screen/auth/signup.dart';
import 'package:flutter_application_1/theme/pawstay_theme.dart';
import 'package:flutter_application_1/Screen/auth/login.dart';
import 'package:flutter_application_1/Screen/auth/forgot_password.dart';

void main() {
  group('PawStay Responsive Utilities Tests', () {
    testWidgets('accurately identifies device breakpoints and aspect ratios', (
      WidgetTester tester,
    ) async {
      // Simulate Vivo / compact phone: 360 x 720
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(PawStayResponsive.width(context), 360.0);
              expect(PawStayResponsive.isCompact(context), isTrue);
              expect(PawStayResponsive.isMobile(context), isTrue);
              expect(PawStayResponsive.isTablet(context), isFalse);
              expect(PawStayResponsive.horizontalPadding(context), 14.0);

              final ratio = PawStayResponsive.gridAspectRatio(
                context: context,
                baseRatio: 1.25,
                compactRatio: 1.15,
              );
              expect(ratio, 1.15);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('scales dimensions correctly on standard iPhone 393 x 852', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(PawStayResponsive.isCompact(context), isFalse);
              expect(PawStayResponsive.isMobile(context), isTrue);
              expect(
                PawStayResponsive.horizontalPadding(context),
                PawStayTheme.marginMobile,
              );

              final ratio = PawStayResponsive.gridAspectRatio(
                context: context,
                baseRatio: 0.65,
                compactRatio: 0.58,
              );
              expect(ratio, 0.65);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('Multi-Device Responsive Screen Rendering (Zero Overflow)', () {
    final devices = [
      {'name': 'Vivo Y20 / Compact Android', 'size': const Size(360, 720)},
      {'name': 'Samsung Galaxy A series', 'size': const Size(360, 800)},
      {'name': 'iPhone SE', 'size': const Size(375, 667)},
      {'name': 'iPhone 15 / Galaxy S23', 'size': const Size(393, 852)},
      {'name': 'iPhone 15 Pro Max', 'size': const Size(430, 932)},
    ];

    for (final device in devices) {
      final name = device['name'] as String;
      final size = device['size'] as Size;

      testWidgets(
        'LoginScreen renders cleanly without overflow on $name ($size)',
        (WidgetTester tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text('PawStay'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('ForgotPasswordScreen renders without overflow on 360x720', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SignupScreen renders without overflow on 360x720', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Account'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('MaterialApp clamps extreme system textScaler properly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? effectiveTextScale;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.5), // extreme system font setting
          ),
          child: MaterialApp(
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: mediaQuery.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.15,
                  ),
                ),
                child: child!,
              );
            },
            home: Builder(
              builder: (context) {
                effectiveTextScale = MediaQuery.textScalerOf(
                  context,
                ).scale(1.0);
                return const Scaffold(body: Text('PawStay Responsive'));
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(effectiveTextScale, isNotNull);
      expect(effectiveTextScale, closeTo(1.15, 0.01));
      expect(find.text('PawStay Responsive'), findsOneWidget);
    });
  });
}
