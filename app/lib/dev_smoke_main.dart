import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = SmartSaveBackend.create(SmartSaveConfig.fromEnvironment());
  await backend.initialize();
  runApp(_DevSmokeApp(backend: backend));
}

final class _DevSmokeApp extends StatelessWidget {
  const _DevSmokeApp({required this.backend});

  final SmartSaveBackend backend;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SmartSave developer smoke test',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: _DevSmokeScreen(backend: backend),
      );
}

final class _DevSmokeScreen extends StatefulWidget {
  const _DevSmokeScreen({required this.backend});

  final SmartSaveBackend backend;

  @override
  State<_DevSmokeScreen> createState() => _DevSmokeScreenState();
}

final class _DevSmokeScreenState extends State<_DevSmokeScreen> {
  final _pinController = TextEditingController();
  final _events = <String>[];
  final _banks = <DiscoveredBank>[];
  StreamSubscription<SmartSaveEvent>? _eventSubscription;

  SmartSaveController get _controller => widget.backend.controller;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _controller.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, _describeEvent(event));
        if (_events.length > 100) _events.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pinController.dispose();
    unawaited(widget.backend.dispose());
    super.dispose();
  }

  Future<void> _showResult<T>(
    Future<ActionResult<T>> operation,
  ) async {
    final result = await operation;
    if (!mounted || result is ActionSuccess<T>) return;
    final error = result.errorOrNull;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${error.code.name}: ${error.message}')),
    );
  }

  Future<void> _scan() async {
    final result = await _controller.scan();
    if (!mounted) return;
    if (result is ActionSuccess<List<DiscoveredBank>>) {
      setState(() {
        _banks
          ..clear()
          ..addAll(result.value);
      });
    } else {
      await _showResult(Future.value(result));
    }
  }

  String _text(Object? value) => value?.toString() ?? '—';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('SmartSave developer smoke test')),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final state = _controller.state;
            final transactions = state.transactions.take(10).toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(
                    'State',
                    [
                      'Mode: ${state.mode.name}',
                      'Link: ${state.link.name}',
                      'Auth: ${state.auth.name}',
                      'Lock: ${state.lock.name}',
                      'Device total: ${_text(state.deviceTotal)}',
                      'Device sequence: ${_text(state.deviceSeq)}',
                      'Sync status: ${state.syncStatus.name}',
                      'Last error: ${state.lastError == null ? '—' : '${state.lastError!.code.name}: ${state.lastError!.message}'}',
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionButton(
                        'Check Bluetooth',
                        () => _showResult(_controller.ensureBluetoothReady()),
                      ),
                      _actionButton('Scan', _scan),
                      _actionButton(
                        'Sync',
                        () => _showResult(_controller.sync()),
                      ),
                      _actionButton(
                        'Disconnect',
                        () => _showResult(_controller.disconnect()),
                      ),
                      _actionButton(
                        'Lock bank',
                        () => _showResult(_controller.lockBank()),
                      ),
                      if (widget.backend.mockControls != null)
                        _actionButton(
                          'Drop P5 coin',
                          () async {
                            widget.backend.mockControls!
                                .dropCoin(Denomination.php5);
                          },
                        ),
                    ],
                  ),
                  if (_banks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Banks found',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._banks.map(
                      (bank) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(bank.name),
                        subtitle: Text(bank.id),
                        onTap: () => _showResult(_controller.connect(bank)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    maxLength: 4,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _actionButton(
                        'Set PIN',
                        () => _showResult(
                          _controller.setInitialPin(_pinController.text),
                        ),
                      ),
                      _actionButton(
                        'Login',
                        () => _showResult(
                          _controller.login(_pinController.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Newest transactions',
                    transactions.isEmpty
                        ? ['None']
                        : transactions
                            .map((transaction) =>
                                '${transaction.type.name}: ${transaction.amount} (${transaction.timestamp})')
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Event log',
                    _events.isEmpty ? ['None'] : _events,
                    scrollable: true,
                  ),
                ],
              ),
            );
          },
        ),
      );

  Widget _actionButton(String label, Future<void> Function() action) =>
      ElevatedButton(
        onPressed: () => unawaited(action()),
        child: Text(label),
      );

  Widget _section(
    String title,
    List<String> lines, {
    bool scrollable = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (scrollable)
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (context, index) => Text(lines[index]),
              ),
            )
          else
            ...lines.map(Text.new),
        ],
      );

  String _describeEvent(SmartSaveEvent event) => switch (event) {
        CoinReceived(:final transaction) =>
          'CoinReceived ${transaction.amount}',
        BalanceChanged(:final oldTotal, :final newTotal) =>
          'BalanceChanged $oldTotal -> $newTotal',
        LockChanged(:final lock) => 'LockChanged ${lock.name}',
        AutoRelocked() => 'AutoRelocked',
        GoalReached(:final goal) => 'GoalReached ${goal.name}',
        ReconciliationApplied(:final delta) => 'ReconciliationApplied $delta',
        DeviceAnomaly(:final kind) => 'DeviceAnomaly ${kind.name}',
        ErrorRaised(:final error) => 'ErrorRaised ${error.code.name}',
        LinkChanged(:final link) => 'LinkChanged ${link.name}',
      };
}
