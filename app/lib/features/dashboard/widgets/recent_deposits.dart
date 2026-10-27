import 'package:flutter/material.dart';
import 'package:smartsave_backend/smartsave_backend.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';

/// Returns the human-readable label for a transaction on the dashboard.
///
/// Deposits show the coin value; other types use a fixed friendly label.
String transactionLabel(SavingsTransaction txn) {
  switch (txn.type) {
    case TransactionType.deposit:
      return txn.denomination == null
          ? 'Deposit'
          : '${formatPeso(txn.denomination!.value)} coin';
    case TransactionType.redemption:
      return 'Goal redeemed';
    case TransactionType.adjustment:
      return 'Balance correction';
    case TransactionType.openingBalance:
      return 'Starting balance';
  }
}

/// Formats a transaction timestamp as `mm-dd-yy HH:mm` (24-hour clock).
///
/// `syncedLate` entries use the same fixed format; no "around"/"today" wordings.
String transactionTimeLabel(SavingsTransaction txn, DateTime now) {
  return formatDateTime(txn.timestamp, now);
}

/// A coin-shaped badge showing the denomination value for deposits, or an
/// appropriate icon for other transaction types.
class TransactionBadge extends StatelessWidget {
  const TransactionBadge({super.key, required this.transaction});

  final SavingsTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final txn = transaction;
    if (txn.type == TransactionType.deposit && txn.denomination != null) {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SmartSaveTokens.primarySoft.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: SmartSaveTokens.primary.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Text(
          '₱${txn.denomination!.value}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: SmartSaveTokens.primary,
          ),
        ),
      );
    }
    final icon = switch (txn.type) {
      TransactionType.redemption => Icons.card_giftcard_outlined,
      TransactionType.adjustment => Icons.tune_outlined,
      TransactionType.openingBalance => Icons.account_balance_outlined,
      TransactionType.deposit => Icons.payments_outlined,
    };
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SmartSaveTokens.primarySoft.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: SmartSaveTokens.primary, size: 22),
    );
  }
}

/// A single row in the recent deposits list.
class RecentDepositTile extends StatelessWidget {
  const RecentDepositTile({
    super.key,
    required this.transaction,
    required this.now,
  });

  final SavingsTransaction transaction;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final txn = transaction;
    final isNegative = txn.amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          TransactionBadge(transaction: txn),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transactionLabel(txn),
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  transactionTimeLabel(txn, now),
                  style: SmartSaveTokens.body.copyWith(
                    color: SmartSaveTokens.inkSoft,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatSignedPeso(txn.amount),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isNegative ? SmartSaveTokens.accent : SmartSaveTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the latest transactions, or a friendly empty state.
class RecentDeposits extends StatelessWidget {
  const RecentDeposits({
    super.key,
    required this.transactions,
    required this.now,
  });

  /// Latest transactions, newest first. Only the first 5 are shown.
  final List<SavingsTransaction> transactions;

  /// Current time for relative labels.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final items = transactions.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent deposits',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 40,
                        color: SmartSaveTokens.inkSoft,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No transactions yet',
                        style: SmartSaveTokens.body.copyWith(
                          color: SmartSaveTokens.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map(
                (txn) => RecentDepositTile(transaction: txn, now: now),
              ),
          ],
        ),
      ),
    );
  }
}
