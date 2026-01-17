import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/loyalty_transaction.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/services/loyalty_service.dart';

class LoyaltyHistoryScreen extends StatefulWidget {
  const LoyaltyHistoryScreen({super.key});

  @override
  State<LoyaltyHistoryScreen> createState() => _LoyaltyHistoryScreenState();
}

class _LoyaltyHistoryScreenState extends State<LoyaltyHistoryScreen> {
  List<LoyaltyTransaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (userData.value?.id == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Utilisateur non connecté';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final transactions = await LoyaltyService.instance.getHistory(
        userData.value!.id,
        limit: 100,
      );

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });

      myCustomPrintStatement('LoyaltyHistory: ${transactions.length} transactions chargées');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement de l\'historique: $e';
      });
      myCustomPrintStatement('LoyaltyHistory: Erreur chargement - $e');
    }
  }

  Future<void> _refreshTransactions() async {
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkThemeProvider>(
      builder: (context, darkThemeProvider, child) {
        return Scaffold(
          backgroundColor: darkThemeProvider.darkTheme 
              ? MyColors.blackColor 
              : MyColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: darkThemeProvider.darkTheme 
                ? MyColors.blackColor 
                : MyColors.whiteColor,
            elevation: 0,
            title: Text(
              translate('pointsHistory'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor 
                    : MyColors.blackColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshTransactions,
            color: MyColors.primaryColor,
            child: _buildContent(darkThemeProvider),
          ),
        );
      },
    );
  }

  Widget _buildContent(DarkThemeProvider darkThemeProvider) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(darkThemeProvider);
    }

    if (_transactions.isEmpty) {
      return _buildEmptyState(darkThemeProvider);
    }

    return Column(
      children: [
        _buildSummaryCard(darkThemeProvider),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionCard(_transactions[index], darkThemeProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(DarkThemeProvider darkThemeProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkThemeProvider.darkTheme 
              ? MyColors.blackColor.withOpacity(0.5)
              : MyColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: MyColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              translate('loadingError'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: darkThemeProvider.darkTheme
                    ? MyColors.whiteColor
                    : MyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? translate('errorOccurred'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor.withOpacity(0.7) 
                    : MyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(translate('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(DarkThemeProvider darkThemeProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkThemeProvider.darkTheme 
              ? MyColors.blackColor.withOpacity(0.5)
              : MyColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: MyColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              translate('noHistory'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: darkThemeProvider.darkTheme
                    ? MyColors.whiteColor
                    : MyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translate('noLoyaltyTransactions'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor.withOpacity(0.7) 
                    : MyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(DarkThemeProvider darkThemeProvider) {
    final userPoints = userData.value?.loyaltyPoints ?? 0.0;
    final totalEarned = userData.value?.totalLoyaltyPointsEarned ?? 0.0;
    final totalSpent = userData.value?.totalLoyaltyPointsSpent ?? 0.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MyColors.primaryColor.withOpacity(0.8),
            MyColors.secondaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MyColors.primaryColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            translate('pointsSummary'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(translate('currentBalance'), '${userPoints.toInt()}', Icons.account_balance_wallet),
              _buildSummaryDivider(),
              _buildSummaryItem(translate('totalEarned'), '${totalEarned.toInt()}', Icons.trending_up),
              _buildSummaryDivider(),
              _buildSummaryItem(translate('totalSpent'), '${totalSpent.toInt()}', Icons.trending_down),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      height: 60,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildTransactionCard(LoyaltyTransaction transaction, DarkThemeProvider darkThemeProvider) {
    final isEarned = transaction.type == 'earned';
    final color = isEarned ? MyColors.success : MyColors.error;
    final icon = isEarned ? Icons.add_circle : Icons.remove_circle;
    final sign = isEarned ? '+' : '-';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme 
            ? MyColors.blackColor.withOpacity(0.5)
            : MyColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.reason,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkThemeProvider.darkTheme 
                        ? MyColors.whiteColor 
                        : MyColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(
                        transaction.timestamp.toDate(),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: darkThemeProvider.darkTheme 
                            ? MyColors.whiteColor.withOpacity(0.7) 
                            : MyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (transaction.amount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${translate('amount')}: ${transaction.amount!.toInt()} MGA',
                    style: TextStyle(
                      fontSize: 11,
                      color: darkThemeProvider.darkTheme 
                          ? MyColors.whiteColor.withOpacity(0.6) 
                          : MyColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ],
                // Afficher les informations des coffres si disponibles
                if (transaction.isChestTransaction) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MyColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: MyColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: MyColors.success,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${translate('reward')}: ${transaction.chestRewardAmount!.toInt()} MGA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MyColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (transaction.rewardMode != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${translate('mode')}: ${_formatRewardMode(transaction.rewardMode!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: darkThemeProvider.darkTheme 
                            ? MyColors.whiteColor.withOpacity(0.5) 
                            : MyColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${transaction.points.toInt()}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${translate('balance')}: ${transaction.balance.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  color: darkThemeProvider.darkTheme 
                      ? MyColors.whiteColor.withOpacity(0.6) 
                      : MyColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formate le mode de récompense pour l'affichage
  String _formatRewardMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'newuser':
        return translate('newUser');
      case 'lucky':
        return translate('lucky');
      case 'standard':
        return translate('standard');
      default:
        return mode;
    }
  }
}