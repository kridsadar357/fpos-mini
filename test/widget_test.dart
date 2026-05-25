import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fuel_pos/core/constants/app_constants.dart';
import 'package:fuel_pos/presentation/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo shows app name and tagline', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(
              size: 120,
              showName: true,
              showTagline: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('ระบบขายน้ำมัน • Mobile & Tablet'), findsOneWidget);
  });
}
