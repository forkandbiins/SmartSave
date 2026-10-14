import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/core/mascot.dart';

void main() {
  testWidgets('PigMascot sizes to the given logical pixels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PigMascot(size: 64),
          ),
        ),
      ),
    );

    expect(find.byType(PigMascot), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.byType(PigMascot));
    expect(box.size, const Size(64, 64));
  });
}
