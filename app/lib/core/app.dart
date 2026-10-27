import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import 'app_gate.dart';
import 'theme.dart';

/// Root widget for the SmartSave UI.
class SmartSaveApp extends StatelessWidget {
  const SmartSaveApp({super.key, required this.controller});

  /// Backend controller created once in `main`.
  final SmartSaveController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSave',
      debugShowCheckedModeBanner: false,
      theme: smartSaveTheme,
      home: AppGate(controller: controller),
    );
  }
}
