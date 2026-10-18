import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../core/theme.dart';
import '../../shared/widgets/smart_save_scaffold.dart';
import '../dashboard/widgets/recent_deposits.dart';

/// Displays the complete transaction history with date filters.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});

  /// Backend controller supplying transaction history.
  final SmartSaveController controller;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _HistoryFilter { all, today, week, month }

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<SavingsTransaction> _transactions() {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;
    if (_filter == _HistoryFilter.today) {
      from = DateTime(now.year, now.month, now.day);
      to = from.add(const Duration(days: 1));
    } else if (_filter == _HistoryFilter.week) {
      final today = DateTime(now.year, now.month, now.day);
      from = today.subtract(Duration(days: today.weekday - 1));
      to = from.add(const Duration(days: 7));
    } else if (_filter == _HistoryFilter.month) {
      from = DateTime(now.year, now.month);
      to = DateTime(now.year, now.month + 1);
    }
    return widget.controller.getTransactions(TransactionQuery(from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final transactions = _transactions();
        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: true,
              title: Text('History'),
              backgroundColor: SmartSaveTokens.background,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SegmentedButton<_HistoryFilter>(
                  segments: const [
                    ButtonSegment(value: _HistoryFilter.all, label: Text('All')),
                    ButtonSegment(value: _HistoryFilter.today, label: Text('Today')),
                    ButtonSegment(value: _HistoryFilter.week, label: Text('Week')),
                    ButtonSegment(value: _HistoryFilter.month, label: Text('Month')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) => setState(() => _filter = value.first),
                ),
              ),
            ),
            if (transactions.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: SmartSaveEmptyState(
                  title: 'No transactions yet',
                  message: 'Your deposits and Bank activity will appear here.',
                  icon: Icons.history,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final showDate = index == 0 ||
                        !_sameDay(transaction.timestamp, transactions[index - 1].timestamp);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                            child: Text(
                              _dateLabel(transaction.timestamp),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: RecentDepositTile(
                              transaction: transaction,
                              now: DateTime.now(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}-${(local.year % 100).toString().padLeft(2, '0')}';
}
