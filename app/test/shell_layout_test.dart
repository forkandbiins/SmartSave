import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/core/home_shell.dart';
import 'package:smartsave/core/theme.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

/// Targets the bottom navigation label, not any matching screen heading.
Finder navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Widget smallShell(SmartSaveController controller) => MaterialApp(
  theme: smartSaveTheme,
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
    child: HomeShell(controller: controller),
  ),
);

void main() {
  for (final profile in SimulatorProfileName.values) {
    late SmartSaveBackend backend;
    setUp(() {
      backend = SmartSaveBackend.create(SmartSaveConfig.mock(profile: profile));
    });
    tearDown(() => backend.dispose());

    testWidgets('HomeShell fits width 320 at text scale 1.5 ($profile)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(smallShell(backend.controller));
      await tester.pumpAndSettle();

      // Every tab is built by the IndexedStack, so this covers Home, History,
      // Goal, Stats and Settings at once.
      expect(tester.takeException(), isNull);
      for (final label in ['Home', 'History', 'Goal', 'Stats', 'Settings']) {
        expect(navLabel(label), findsOneWidget);
      }

      await tester.tap(navLabel('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Bank locked'), findsOneWidget);
      expect(find.textContaining('Balance not synced yet'), findsOneWidget);

      await tester.tap(navLabel('Goal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No goals yet'), findsOneWidget);
    });
  }
}
