import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';

/// Widget d'affichage d'une transaction du portefeuille
/// Suit les conventions du Design System Misy V2
class WalletTransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  final VoidCallback? onTap;
  final bool showDetails;

  const WalletTransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MyColors.backgroundContrast,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MyColors.borderLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: MyColors.blackColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildIcon(),
            hSizedBox,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  vSizedBox05,
                  _buildDescription(),
                  if (showDetails) ...[
                    vSizedBox05,
                    _buildDetails(),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAmount(),
                vSizedBox05,
                _buildStatus(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getIconBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _getIcon(),
    );
  }

  Widget _getIcon() {
    switch (transaction.source) {
      case PaymentSource.airtelMoney:
        return Image.asset(
          MyImagesUrl.airtelMoneyIcon,
          width: 24,
          height: 24,
        );
      case PaymentSource.orangeMoney:
        return Image.asset(
          MyImagesUrl.orangeMoneyIcon,
          width: 24,
          height: 24,
        );
      case PaymentSource.telmaMoney:
        return Image.asset(
          MyImagesUrl.telmaMvolaIcon,
          width: 24,
          height: 24,
        );
      case PaymentSource.creditCard:
        return Image.asset(
          MyImagesUrl.bankCardIcon,
          width: 24,
          height: 24,
        );
      case PaymentSource.tripPayment:
        return Icon(
          Icons.directions_car,
          color: MyColors.whiteColor,
          size: 24,
        );
      case PaymentSource.refund:
        return Icon(
          Icons.undo,
          color: MyColors.whiteColor,
          size: 24,
        );
      case PaymentSource.bonus:
        return Icon(
          Icons.star,
          color: MyColors.whiteColor,
          size: 24,
        );
      case PaymentSource.cashback:
        return Icon(
          Icons.monetization_on,
          color: MyColors.whiteColor,
          size: 24,
        );
      case PaymentSource.transfer:
        return Icon(
          Icons.swap_horiz,
          color: MyColors.whiteColor,
          size: 24,
        );
      case PaymentSource.adjustment:
        return Icon(
          Icons.tune,
          color: MyColors.whiteColor,
          size: 24,
        );
    }
  }

  Color _getIconBackgroundColor() {
    switch (transaction.type) {
      case TransactionType.credit:
        return MyColors.success;
      case TransactionType.debit:
        return MyColors.coralPink;
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: SubHeadingText(
            _getTransactionTitle(),
            color: MyColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        hSizedBox05,
        _buildTypeChip(),
      ],
    );
  }

  String _getTransactionTitle() {
    switch (transaction.source) {
      case PaymentSource.airtelMoney:
        return translate('airtelMoneyPayment');
      case PaymentSource.orangeMoney:
        return translate('orangeMoneyPayment');
      case PaymentSource.telmaMoney:
        return translate('mvolaPayment');
      case PaymentSource.creditCard:
        return translate('creditCardSource');
      case PaymentSource.tripPayment:
        return translate('tripPaymentSource');
      case PaymentSource.refund:
        return translate('refundSource');
      case PaymentSource.bonus:
        return translate('bonusSource');
      case PaymentSource.cashback:
        return translate('cashbackSource');
      case PaymentSource.transfer:
        return translate('transferSource');
      case PaymentSource.adjustment:
        return translate('adjustmentSource');
    }
  }

  Widget _buildTypeChip() {
    Color chipColor;
    String label;
    
    switch (transaction.type) {
      case TransactionType.credit:
        chipColor = MyColors.success;
        label = translate('creditLabel');
        break;
      case TransactionType.debit:
        chipColor = MyColors.coralPink;
        label = translate('debitLabel');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ParagraphText(
        label,
        color: chipColor,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDescription() {
    return ParagraphText(
      transaction.description.isEmpty 
          ? transaction.formattedDescription 
          : transaction.description,
      color: MyColors.textSecondary,
      fontSize: 14,
      maxLines: 2,
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (transaction.referenceId != null && transaction.referenceId!.isNotEmpty)
          _buildDetailRow(translate('referenceLabel'), transaction.referenceId!),
        if (transaction.tripId != null && transaction.tripId!.isNotEmpty)
          _buildDetailRow(translate('trip'), transaction.tripId!),
        _buildDetailRow(translate('dateLabel'), _formatDate(transaction.timestamp)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          ParagraphText(
            '$label: ',
            color: MyColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          Expanded(
            child: ParagraphText(
              value,
              color: MyColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmount() {
    String amountText = transaction.type == TransactionType.credit 
        ? '+${_formatAmount(transaction.amount)}'
        : '-${_formatAmount(transaction.amount)}';
        
    Color amountColor = transaction.type == TransactionType.credit 
        ? MyColors.success 
        : MyColors.coralPink;

    return SubHeadingText(
      amountText,
      color: amountColor,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
  }

  Widget _buildStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          hSizedBox05,
          ParagraphText(
            _getStatusText(),
            color: _getStatusColor(),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (transaction.status) {
      case TransactionStatus.completed:
        return MyColors.success;
      case TransactionStatus.pending:
        return MyColors.warning;
      case TransactionStatus.processing:
        return MyColors.horizonBlue;
      case TransactionStatus.failed:
        return MyColors.error;
      case TransactionStatus.cancelled:
        return MyColors.textSecondary;
      case TransactionStatus.refunded:
        return MyColors.warning;
    }
  }

  String _getStatusText() {
    switch (transaction.status) {
      case TransactionStatus.completed:
        return translate('statusCompleted');
      case TransactionStatus.pending:
        return translate('statusPending');
      case TransactionStatus.processing:
        return translate('statusProcessing');
      case TransactionStatus.failed:
        return translate('statusFailed');
      case TransactionStatus.cancelled:
        return translate('statusCancelled');
      case TransactionStatus.refunded:
        return translate('statusRefunded');
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M MGA';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K MGA';
    } else {
      return '${amount.toStringAsFixed(0)} MGA';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return translate('agoMinutes').replaceAll('%s', '${difference.inMinutes}');
      } else {
        return translate('agoHours').replaceAll('%s', '${difference.inHours}');
      }
    } else if (difference.inDays == 1) {
      return translate('yesterdayAt').replaceAll('%s', DateFormat('HH:mm').format(date));
    } else if (difference.inDays < 7) {
      return translate('agoDays').replaceAll('%s', '${difference.inDays}');
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

/// Widget pour afficher une liste de transactions avec pagination
class WalletTransactionsList extends StatelessWidget {
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final Function(WalletTransaction)? onTransactionTap;

  const WalletTransactionsList({
    super.key,
    required this.transactions,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty && !isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < transactions.length) {
          return WalletTransactionCard(
            transaction: transactions[index],
            onTap: onTransactionTap != null 
                ? () => onTransactionTap!(transactions[index])
                : null,
          );
        } else {
          // Bouton "Charger plus"
          return Container(
            margin: const EdgeInsets.all(16),
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: onLoadMore,
                      child: ParagraphText(
                        translate('loadMore'),
                        color: MyColors.coralPink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          );
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: MyColors.textSecondary.withOpacity(0.5),
          ),
          vSizedBox2,
          SubHeadingText(
            translate('noTransactions'),
            color: MyColors.textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          vSizedBox,
          ParagraphText(
            translate('transactionsWillAppear'),
            color: MyColors.textSecondary,
            fontSize: 14,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget compact pour afficher le résumé des transactions récentes
class WalletTransactionsSummary extends StatelessWidget {
  final List<WalletTransaction> recentTransactions;
  final VoidCallback? onSeeAllTap;

  const WalletTransactionsSummary({
    super.key,
    required this.recentTransactions,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MyColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SubHeadingText(
                translate('recentTransactions'),
                color: MyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              if (onSeeAllTap != null)
                GestureDetector(
                  onTap: onSeeAllTap,
                  child: ParagraphText(
                    translate('seeAll'),
                    color: MyColors.coralPink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          vSizedBox,
          if (recentTransactions.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTransactions.take(3).length,
              separatorBuilder: (context, index) => Divider(
                color: MyColors.borderLight,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final transaction = recentTransactions[index];
                return _buildCompactTransactionItem(transaction);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompactTransactionItem(WalletTransaction transaction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: transaction.type == TransactionType.credit
                  ? MyColors.success.withOpacity(0.1)
                  : MyColors.coralPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.type == TransactionType.credit
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              color: transaction.type == TransactionType.credit
                  ? MyColors.success
                  : MyColors.coralPink,
              size: 16,
            ),
          ),
          hSizedBox,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ParagraphText(
                  WalletTransactionHelper.getDisplayNameForSource(transaction.source),
                  color: MyColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                ParagraphText(
                  _formatDate(transaction.timestamp),
                  color: MyColors.textSecondary,
                  fontSize: 12,
                ),
              ],
            ),
          ),
          ParagraphText(
            '${transaction.type == TransactionType.credit ? '+' : '-'}${_formatAmount(transaction.amount)}',
            color: transaction.type == TransactionType.credit
                ? MyColors.success
                : MyColors.coralPink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ParagraphText(
          'Aucune transaction récente',
          color: MyColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M MGA';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K MGA';
    } else {
      return '${amount.toStringAsFixed(0)} MGA';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Il y a ${difference.inMinutes} min';
      } else {
        return 'Il y a ${difference.inHours}h';
      }
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}