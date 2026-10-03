# SmartSave

SmartSave is our BS Computer Science coin bank project: an Arduino Uno with an
HM-10 Bluetooth module (the **Bank**) that accepts the new ₱1, ₱5, ₱10, and ₱20
coins, plus a Flutter app that tracks the savings. This repo holds all of it,
and the **Backend** is the part the whole team depends on.

The Backend (`packages/smartsave_backend`) sits between the UI and the Bank. It
does everything the UI should not: it connects to the Bank over Bluetooth,
keeps the Bank's balance as the authority, records each coin as history, tracks
savings goals on the phone, and handles the PIN. The UI only reads the
Backend's state and calls its methods; it never touches Bluetooth.

Until the finished hardware is ready, the **Firmware Stub** (Arduino) and the
**Simulator** (built into the Backend) behave like the real Bank, so you can
build and test the UI without any hardware.

## Repository layout

```text
app/                                  Flutter UI
packages/smartsave_backend/           Flutter Backend package
firmware/smartsave_stub/              Arduino Firmware Stub
docs/                                 Architecture, protocol, API, hardware
SMARTSAVE_BACKEND_PLAN.md             Project plan and ownership rules
```

Start with:

- [Backend API](docs/BACKEND_API.md) — **UI developers read this first**
- [Architecture](docs/ARCHITECTURE.md)
- [Protocol](docs/PROTOCOL.md) — you do not need this to build the UI
- [Hardware testing](docs/HARDWARE_TESTING.md) — Member 1 only

---

# UI development

## 1. Set up (about 15 minutes)

You need Flutter installed, VS Code or Android Studio, and an Android phone
(with USB debugging) or an Android emulator. iPhone testing needs a Mac with
Xcode. You do **not** need any Arduino hardware.

```bash
git clone <repo-url>
cd <repo>/app
flutter pub get
flutter run --dart-define=SMARTSAVE_MODE=mock
```

`--dart-define=SMARTSAVE_MODE=mock` starts the app with a **fake bank** built
into the Backend, so everything works with no hardware. This is the default.

Then run the working example once:

```bash
flutter run -t lib/dev_smoke_main.dart --dart-define=SMARTSAVE_MODE=mock
```

`app/lib/dev_smoke_main.dart` is a plain developer screen owned by Member 1.
Read it to see how the Backend is created and used. **Do not build on it or
edit it**; it is throwaway.

Then read [docs/BACKEND_API.md](docs/BACKEND_API.md) before writing any UI code.

## 2. The rules (read these twice)

| Do | Do not |
|---|---|
| Import only `package:smartsave_backend/smartsave_backend.dart` (and `testing.dart` inside tests) | Import anything from `smartsave_backend/src/`, `flutter_reactive_ble`, or `permission_handler` |
| Read the balance from `controller.state` / `summary` | Add coins up yourself or compute the balance |
| Call controller methods and read the `ActionResult` | Build or parse protocol text like `COIN:5,1` or `HELLO` |
| Show the error `code` as friendly text of your own | Show raw error messages to users |
| Ask for Backend changes with a `backend-request` issue | Edit anything inside `packages/smartsave_backend/` |
| Keep money as whole-peso `int` values | Use `double` for money |
| Keep the PIN only in the text field while typing | Store, print, or log the PIN |

CI fails if UI code imports Backend internals or a Bluetooth package.

## 3. How the Backend talks to your UI

Three ideas cover the whole API:

1. **State is what is true now.** `controller.state` is one immutable object.
   The controller is a `ChangeNotifier`, so you rebuild the screen with
   `ListenableBuilder`.
2. **Events are what just happened.** `controller.events` is a stream. Use it
   for one-off things such as a "+₱5" animation or a snackbar. Do not store
   events as data.
3. **Actions never throw.** Every controller method returns an
   `ActionResult`: success or failure. Handle it inline; no `try/catch`.

```dart
// main.dart — create the Backend ONCE and pass the controller down.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = SmartSaveBackend.create(SmartSaveConfig.fromEnvironment());
  await backend.initialize();
  runApp(MyApp(controller: backend.controller));
}

// Any screen — rebuild whenever the state changes.
ListenableBuilder(
  listenable: controller,
  builder: (context, _) {
    final total = controller.state.deviceTotal;
    if (total == null) return const Text('Not synced yet');
    return Text('₱$total');
  },
);

// A button — actions return a result instead of throwing.
final result = await controller.login(pin);
result.when(
  success: (_) { /* go to the dashboard */ },
  failure: (error) { /* show your own message for error.code */ },
);

// One-off reactions — subscribe in initState, cancel in dispose.
controller.events.listen((event) {
  if (event is CoinReceived) { /* play the coin animation */ }
});
```

> Method names above follow the plan. **`docs/BACKEND_API.md` is the source of
> truth** for exact names and signatures. If the two ever differ, follow the
> API doc and tell Member 1.

## 4. What to build

The five mockups in the proposal become these screens.

| Screen | Owner | Shows | Backend data and actions |
|---|---|---|---|
| **Dashboard** | Member 2 | Total savings, goal progress bar, today / this week / deposit count / last deposit, recent deposits | `state.deviceTotal`, `summary`, `getTransactions`, `statistics`, `state.goals` |
| **Savings Goal** | Member 2 | Goal name, target, progress ring, allocated amount, add or release money, **Redeem** | `createGoal`, `updateGoal`, `deleteGoal`, `allocateToGoal`, `releaseFromGoal`, `redeemGoal`, `summary.available` |
| **Statistics** | Member 2 | Daily / weekly / monthly bars, highest day, average per day, transaction count | `statistics(range)` |
| **Deposit History** | Member 3 | All / Today / This Week / This Month filters, list grouped by day | `getTransactions(TransactionQuery)` |
| **Connection / Scan** | Member 3 | Bluetooth status, list of banks, connect, reconnect, link state | `ensureBluetoothReady`, `scan`, `connect`, `reconnectLast`, `disconnect`, `state.link` |
| **PIN setup and login** | Member 3 | First-time PIN, login, lockout countdown, change PIN | `setInitialPin`, `login`, `logout`, `changePin`, `state.auth`, `state.lockoutEndsAt` |
| **Bank status and Settings** | Member 3 | Locked / unlocked, Lock button, manual balance correction, reset local data | `lockBank`, `adjustBalance`, `resetLocalData`, `state.lock` |
| **Shared widgets** | Member 3 | Peso text, coin icons, loading and empty states, error banner, confirmation dialogs | none (pure UI) |

**One difference from the mockups.** The Bank Control mockup shows "swipe up to
unlock". In the final design the bank unlocks only when a **goal is redeemed**
(Savings Goal screen): money you put toward a goal is only set aside in the
app, and redeeming it unlocks the bank and removes that amount. So "unlock"
is the Redeem button on a goal, not a separate swipe. "Recent access" in the
mockup is the list of redemption transactions.

## 5. The screens you must handle (login flow)

The Backend connects and syncs immediately. **Hiding the balance until login is
the UI's job.** React to `state.link` and `state.auth` like this:

| State | What the UI shows |
|---|---|
| `link` is `disconnected` | Connection screen with a Connect / Reconnect button |
| `link` is `scanning`, `connecting`, or `handshaking` | Progress indicator |
| `link` is `ready` and `auth` is `pinNotSet` | First-time **Set PIN** screen |
| `auth` is `loggedOut` | **Login** screen |
| `auth` is `lockedOut` | "Too many wrong PINs" with a countdown to `lockoutEndsAt` |
| `auth` is `loggedIn` | The app (dashboard and tabs) |
| `deviceTotal` is `null` | "Not synced yet" (never show ₱0) |
| `sync` is `syncing` | Small progress indicator, keep showing the last balance |
| `lastError` is set | An error banner built from the error `code` |

Going back to `disconnected` also logs the user out. The Backend clears the PIN
when the link drops, so send the user to the login screen again after a
reconnect.

## 6. Display rules for money and history

- Money is a whole-peso `int`. Format it like `₱1,250` with a thousands
  separator, and never use `double`.
- A transaction has a **type**. Show each one differently:
  `deposit` (+), `redemption` (−, linked to a goal), `adjustment` (label it
  "Balance correction"), `openingBalance` (label it "Starting balance").
- A transaction has a **time accuracy**. If it is `syncedLate`, the coin was
  dropped while the app was away, so show the time as approximate (for example
  "synced at 3:40 PM").
- `summary.available` is money not yet set aside for a goal. A goal can only
  receive up to `available`.
- If `summary.overAllocatedBy` is above 0, goals hold more than the bank has
  (this can happen after a manual correction). Show a warning.
- Show the maximum bank balance as ₱99,999 where it matters.

## 7. Where to put files

```text
app/lib/
  main.dart                   Member 2   creates the Backend once
  dev_smoke_main.dart         Member 1   do not edit
  core/                       Member 2   theme, routing, app setup
  features/
    dashboard/                Member 2
    goals/                    Member 2
    statistics/               Member 2
    history/                  Member 3
    auth/                     Member 3
    connection/               Member 3
    settings/                 Member 3
  shared/widgets/             Member 3   reusable widgets for everyone
```

Stay inside your own folders. Need a shared widget? Ask Member 3 or open a small
pull request into `shared/widgets/`.

## 8. Suggested order of work

1. **Days 1–2:** Member 2 sets up `main.dart`, theme, and navigation (five tabs:
   Home, History, Goal, Stats, Settings). Member 3 builds the shared widgets.
2. **Build screens from fixtures.** `DemoFixtures` in `testing.dart` gives you
   ready-made states (for example `DemoFixtures.demoState()`), so you can design
   every screen before wiring any logic.
3. **Wire to the controller in mock mode.** The mock bank has two profiles:
   `fresh` (no PIN, ₱0) and `demo` (PIN `1234`, ₱1,250). See `BACKEND_API.md`
   for how to choose one.
4. **Test with fake coins.** In mock mode, `backend.mockControls` can drop a
   coin, start automatic coins, cut the connection, and reset the fake bank.
   Member 3 should put these in a developer-only menu.
5. **Real Bluetooth last.** Member 1 will tell you when BLE mode is ready. Then
   run with `--dart-define=SMARTSAVE_MODE=ble` on a physical Android phone.

## 9. Before you open a pull request

A screen is done when:

- [ ] It works in mock mode with the `fresh` and the `demo` profile.
- [ ] It handles every state in section 5 that applies to it, including empty
      lists and `deviceTotal == null`.
- [ ] Every action's failure shows a friendly message.
- [ ] Money uses the peso format and `int` values.
- [ ] There is at least one widget test using `DemoFixtures`.
- [ ] `flutter analyze` and `flutter test` pass in `app/`.
- [ ] No imports from `smartsave_backend/src` or Bluetooth packages.
- [ ] The PR description says which screen it covers and includes a screenshot.

## 10. Git workflow

- Branch from `main`: `ui/m2/dashboard`, `ui/m3/history`, and so on. Never
  commit to `main` directly.
- Keep pull requests small, one screen or one feature each.
- Pull `main` every day before you start (`git pull --rebase origin main`).
- Commit messages: `feat(ui): add history filters`, `fix(ui): ...`.
- Shared files (`main.dart`, routing, theme, `pubspec.yaml`) belong to Member 2.
  Change them in small pull requests, and tell the others.
- If `pubspec.lock` conflicts, accept the version from `main` and run
  `flutter pub get`.

## 11. Need something from the Backend?

Do not edit `packages/smartsave_backend/`. Open an issue with the
**backend-request** template and include:

- the screen you are building,
- what data or action you need,
- what you tried and what the Backend returned.

Before you ask, check `BACKEND_API.md`; the answer is usually there.

---

## Operating modes

The Backend has two runtime modes:

1. **Mock mode** (`SMARTSAVE_MODE=mock`, the default) uses the Dart Simulator.
2. **BLE mode** (`SMARTSAVE_MODE=ble`) uses the HM-10 transport.

The plan calls the BLE deployment stages **Mode 2: Hardware testing** and
**Mode 3: Final system**. They use the same Backend and BLE mode; the
difference is the Bank firmware and hardware maturity, not a third Dart
runtime mode.

UI developers work in mock mode. BLE mode needs a physical Android phone (or
an iPhone with a Mac), a Bank running the Firmware Stub or final firmware, and
Bluetooth permissions. Member 1 will announce when it is ready to use.

## Ownership

Per `SMARTSAVE_BACKEND_PLAN.md`, Member 1 owns the Backend, Arduino integration,
Firmware Stub, and hardware bring-up. Member 2 owns dashboard, balance, goals,
and statistics UI. Member 3 owns history, authentication/PIN, settings,
connection/scan, and shared UI. UI developers request Backend changes through a
`backend-request` issue rather than editing `packages/smartsave_backend`.
