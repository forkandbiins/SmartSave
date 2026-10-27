import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'app_gate.dart';
import 'theme.dart';

/// Root widget for the SmartSave UI.
class SmartSaveApp extends StatelessWidget {
  const SmartSaveApp({super.key, required this.backend});

  /// Backend created once in `main`.
  final SmartSaveBackend backend;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSave',
      debugShowCheckedModeBanner: false,
      theme: smartSaveTheme,
      home: _AppLifetime(backend: backend),
    );
  }
}

final class _AppLifetime extends StatefulWidget {
  const _AppLifetime({required this.backend});

  final SmartSaveBackend backend;

  @override
  State<_AppLifetime> createState() => _AppLifetimeState();
}

final class _AppLifetimeState extends State<_AppLifetime> {
  @override
  void dispose() {
    unawaited(widget.backend.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppGate(controller: widget.backend.controller);
}
