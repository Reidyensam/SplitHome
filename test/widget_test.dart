import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splithome/main.dart'; // Asegúrate de que el path sea correcto

void main() {
  testWidgets('SplitHomeApp loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(SplitHomeApp());

    // Verifica que el MaterialApp esté presente
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}