import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/core/theme.dart';
import 'package:smartsave/features/settings/settings_screen.dart';
import 'package:smartsave_backend/smartsave_backend.dart';
import 'package:smartsave_backend/testing.dart';

void main() {
  late SmartSaveBackend backend;
  late FakeClock clock;

  setUp(() {
    // Created outside the widget test so the mock transport's simulator ticker
    // is a real timer rather than a pending fake one.
    clock = FakeClock(DateTime(2026, 1, 13, 9));
    backend = SmartSaveBackend.create(
      SmartSaveConfig.mock(profile: SimulatorProfileName.demo),
      clock: clock,
    );
  });

  tearDown(() => backend.dispose());

  /// Connects to the demo bank and logs in with its PIN (1234).
  Future<void> signIn() async {
    final scan = await backend.controller.scan();
    final bank = scan.valueOrNull!.single;
    final connected = await backend.controller.connect(bank);
    expect(connected.isSuccess, isTrue, reason: 'connect failed');
    final loggedIn = await backend.controller.login('1234');
    expect(loggedIn.isSuccess, isTrue, reason: 'login failed');
  }

  Widget host(SmartSaveController controller, {double textScale = 1.0}) {
    return MaterialApp(
      theme: smartSaveTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      ),
    );
  }

  Future<void> openChangePin(WidgetTester tester) async {
    final tile = find.text('Change PIN');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  /// Gives the backend command chain a chance to finish.
  ///
  /// The mock transport is built in `setUp`, outside the widget test's fake
  /// async zone, so `ProtocolDeviceClient` completes its completers from the
  /// real zone. `runAsync` gives the real event loop a turn; the interleaved
  /// `pump` calls flush the fake-zone continuations that follow.
  Future<void> settleBackend(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pump();
  }

  /// Fills the three PIN fields and taps Save, then settles the request.
  Future<void> submitPin(
    WidgetTester tester, {
    required String current,
    required String next,
    required String confirm,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), confirm);
    await tester.tap(saveButton());
    await settleBackend(tester);
  }

  testWidgets('Change PIN asks for current, new and confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(host(backend.controller));
    await openChangePin(tester);

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Current PIN'), findsOneWidget);
    expect(find.text('New PIN'), findsOneWidget);
    expect(find.text('Confirm new PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Change PIN validates the fields before calling the device', (
    tester,
  ) async {
    await tester.pumpWidget(host(backend.controller));
    await openChangePin(tester);

    // New PIN equal to the current one.
    await submitPin(tester, current: '1234', next: '1234', confirm: '1234');
    expect(
      find.text('Choose a PIN different from your current one.'),
      findsOneWidget,
    );

    // Confirmation does not match.
    await submitPin(tester, current: '1234', next: '5678', confirm: '9999');
    expect(find.text('The new PINs do not match.'), findsOneWidget);

    // Current PIN is not four digits.
    await submitPin(tester, current: '12', next: '5678', confirm: '5678');
    expect(find.text('Enter your current 4-digit PIN.'), findsOneWidget);

    // A missing new PIN.
    await submitPin(tester, current: '1234', next: '', confirm: '');
    expect(find.text('Enter a new 4-digit PIN.'), findsOneWidget);

    // Validation failures never reach the backend.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('three wrong current PINs lock the form with a countdown', (
    tester,
  ) async {
    await signIn();
    await tester.pumpWidget(host(backend.controller));
    await openChangePin(tester);

    await submitPin(tester, current: '0001', next: '5678', confirm: '5678');
    expect(find.text('Incorrect PIN. 2 tries left.'), findsOneWidget);

    await submitPin(tester, current: '0002', next: '5678', confirm: '5678');
    expect(find.text('Incorrect PIN. 1 tries left.'), findsOneWidget);

    await submitPin(tester, current: '0003', next: '5678', confirm: '5678');
    expect(find.text('Incorrect PIN. 1 tries left.'), findsNothing);
    expect(find.textContaining('Too many incorrect attempts.'), findsOneWidget);
    expect(find.textContaining('Try again in 30s.'), findsOneWidget);

    // The form is paused: Save is disabled and every field is disabled.
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }

    // After the lockout duration the form comes back.
    clock.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.textContaining('Try again in'), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isTrue);
    }
  });

  testWidgets('a correct current PIN changes the PIN and closes the dialog', (
    tester,
  ) async {
    await signIn();
    await tester.pumpWidget(host(backend.controller));
    await openChangePin(tester);

    await submitPin(tester, current: '1234', next: '5678', confirm: '5678');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('PIN changed.'), findsOneWidget);

    // The device now accepts the new PIN.
    final relogin = await backend.controller.login('5678');
    expect(relogin.isSuccess, isTrue);
  });

  testWidgets('Change PIN dialog fits width 320 at text scale 1.5', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(backend.controller, textScale: 1.5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openChangePin(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Current PIN'), findsOneWidget);
    expect(find.text('New PIN'), findsOneWidget);
    expect(find.text('Confirm new PIN'), findsOneWidget);

    // Showing the inline errors must not overflow either.
    await submitPin(tester, current: '12', next: '9999', confirm: '0000');
    expect(tester.takeException(), isNull);
    expect(find.text('Enter your current 4-digit PIN.'), findsOneWidget);
  });
}
