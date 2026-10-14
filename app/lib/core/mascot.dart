import 'package:flutter/material.dart';

import 'theme.dart';

/// Placeholder pig. The final pig-eating-coin-shaped-cheese-bread art
/// replaces this drawing in this one file.
class PigMascot extends StatelessWidget {
  const PigMascot({super.key, required this.size});

  /// Width and height of the mascot box, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: SmartSaveTokens.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.savings_outlined,
          size: size * 0.55,
          color: SmartSaveTokens.primary,
          semanticLabel: 'SmartSave pig mascot',
        ),
      ),
    );
  }
}
