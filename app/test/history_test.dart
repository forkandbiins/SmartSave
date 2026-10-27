import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/core/theme.dart';
import 'package:smartsave/features/history/history_screen.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

void main() {
  // Created outside the widget test so its mock-transport ticker is a real
  // timer rather than a pending fake one.
  late SmartSaveBackend backend;

  setUp(() {
    backend = SmartSaveBackend.create(SmartSaveConfig.mock());
  });

  tearDown(() => backend.dispose());

  testWidgets(
    'History filter labels stay on one line at 320dp and text scale 1.5',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: smartSaveTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: HistoryScreen(controller: backend.controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final label in const ['All', 'Today', 'Week', 'Month']) {
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }
      // Wrapping would make a label taller than a single line, so every label
      // must be exactly as tall as the shortest one, which cannot wrap.
      final singleLineHeight = tester.getSize(find.text('All')).height;
      for (final label in const ['Today', 'Week', 'Month']) {
        expect(
          tester.getSize(find.text(label)).height,
          singleLineHeight,
          reason: '"$label" wrapped onto more than one line',
        );
      }
    },
  );
}
