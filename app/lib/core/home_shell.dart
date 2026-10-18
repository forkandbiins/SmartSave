import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/history/history_screen.dart';
import '../features/goals/widgets/goal_card.dart';
import '../features/settings/settings_screen.dart';
import 'theme.dart';

/// Logged-in shell with five tabs. Goal lists [SmartSaveState.goals]; other tabs are placeholders.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  /// Backend controller whose state drives the Goal tab.
  final SmartSaveController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartSaveTokens.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(controller: widget.controller),
            HistoryScreen(controller: widget.controller),
            _GoalsTab(controller: widget.controller),
            const _PlaceholderTab('Stats'),
            SettingsScreen(controller: widget.controller),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: SmartSaveTokens.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SmartSaveTokens.radiusCard),
          ),
          boxShadow: SmartSaveTokens.softShadows,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SmartSaveTokens.radiusCard),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.flag_outlined),
                selectedIcon: Icon(Icons.flag),
                label: 'Goal',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({required this.controller});

  final SmartSaveController controller;

  @override
  Widget build(BuildContext context) {
    final goals = controller.state.goals;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (context, index) => GoalCard(
        goal: goals[index],
        onRedeem: goals[index].isReached
            ? () => _redeemGoal(context, goals[index])
            : null,
      ),
    );
  }

  Future<void> _redeemGoal(BuildContext context, SavingsGoal goal) async {
    final pin = TextEditingController();
    final enteredPin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem goal'),
        content: TextField(
          controller: pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'Bank PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pin.text),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    pin.dispose();
    if (enteredPin == null || !context.mounted) return;
    final result = await controller.redeemGoal(goal.id, enteredPin);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Goal redeemed. Your Bank is unlocked.'
              : 'Could not redeem the goal. Check your PIN and try again.',
        ),
      ),
    );
  }
}
