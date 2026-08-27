import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jubileu_app/api_client.dart';
import 'package:jubileu_app/main.dart';

void main() {
  testWidgets('shows the local access screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(onLogin: (LoginData _) async {})),
    );

    expect(find.text('Jubileu'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
