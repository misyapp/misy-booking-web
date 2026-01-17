import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';

/// Widget d'affichage du solde du portefeuille avec animations
/// Suit les conventions du Design System Misy V2
class WalletBalanceWidget extends StatefulWidget {
  final VoidCallback? onCreditTap;
  final VoidCallback? onHistoryTap;
  final bool showActions;

  const WalletBalanceWidget({
    super.key,
    this.onCreditTap,
    this.onHistoryTap,
    this.showActions = true,
  });

  @override
  State<WalletBalanceWidget> createState() => _WalletBalanceWidgetState();
}

class _WalletBalanceWidgetState extends State<WalletBalanceWidget>
    with TickerProviderStateMixin {
  late AnimationController _balanceController;
  late AnimationController _pulseController;
  late Animation<double> _balanceAnimation;
  late Animation<double> _pulseAnimation;
  double _previousBalance = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Animation pour le changement de solde
    _balanceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Animation de pulsation pour les alertes
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _balanceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _balanceController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Démarrer l'animation initiale
    _balanceController.forward();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleBalanceChange(double newBalance) {
    if (_previousBalance != newBalance && _previousBalance > 0) {
      _balanceController.reset();
      _balanceController.forward();
      
      // Pulsation si solde faible
      if (newBalance < 10000) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
    _previousBalance = newBalance;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        myCustomPrintStatement('WalletBalanceWidget: building with state ${walletProvider.state}');
        
        // Gérer les animations selon le solde
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleBalanceChange(walletProvider.balance);
        });

        return Container(
          margin: const EdgeInsets.all(16),
          // Fond en dégradé adaptatif au thème
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Provider.of<DarkThemeProvider>(context).darkTheme
                  ? [
                      const Color(0xFF2D3748), // Gris bleuté foncé
                      const Color(0xFF1A202C), // Gris très foncé
                      const Color(0xFF2D2D2D), // Gris foncé
                    ]
                  : [
                      const Color(0xFFE3F2FD), // Bleu très clair
                      const Color(0xFFE8EAF6), // Violet très doux
                      const Color(0xFFF3E5F5), // Violet encore plus doux
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              // Carte rectangulaire moderne
              Container(
                width: double.infinity,
                height: 180,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // Fond adaptatif au thème
                  color: MyColors.cardThemeColor(),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Ombre flottante moderne
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    // Ombre secondaire plus subtile
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec icône portefeuille minimaliste
                    Row(
                      children: [
                        // Icône portefeuille minimaliste
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: MyColors.textSecondaryTheme(),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        // Texte "Solde Misy"
                        Text(
                          translate('misyBalance'),
                          style: TextStyle(
                            color: MyColors.blackThemeColor(),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins', // Police sans serif moderne
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Zone centrale avec le solde
                    Center(
                      child: Column(
                        children: [
                          // Libellé "Solde" en petit
                          Text(
                            translate('walletBalanceLabel'),
                            style: TextStyle(
                              color: MyColors.textSecondaryTheme(),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Montant avec animation et effet d'ombre
                          AnimatedBuilder(
                            animation: _balanceAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.95 + (0.05 * _balanceAnimation.value),
                                child: Container(
                                  // Effet d'ombre sur le texte du montant
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    walletProvider.formattedBalance,
                                    style: TextStyle(
                                      color: MyColors.blackThemeColor(),
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                      letterSpacing: -1.5,
                                      height: 1.1,
                                      shadows: [
                                        // Effet d'ombre subtile sur les chiffres
                                        Shadow(
                                          color: Colors.black.withOpacity(0.1),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Boutons en dessous de la carte
              if (widget.showActions) ...[
                const SizedBox(height: 16),
                _buildActionButtons(walletProvider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardStatusIndicator(WalletProvider walletProvider) {
    Color statusColor;
    IconData statusIcon;
    Color backgroundColor;
    
    if (walletProvider.isLoading) {
      statusColor = MyColors.primaryColor;
      backgroundColor = MyColors.primaryColor.withOpacity(0.1);
      statusIcon = Icons.sync;
    } else if (walletProvider.hasError) {
      statusColor = Colors.red.shade600;
      backgroundColor = Colors.red.withOpacity(0.1);
      statusIcon = Icons.error_outline;
    } else if (walletProvider.hasLowBalance) {
      statusColor = Colors.orange.shade600;
      backgroundColor = Colors.orange.withOpacity(0.1);
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.green.shade600;
      backgroundColor = Colors.green.withOpacity(0.1);
      statusIcon = Icons.check_circle_outline;
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        statusIcon,
        color: statusColor,
        size: 20,
      ),
    );
  }

  Widget _buildBalanceIndicator(Wallet wallet) {
    double percentage = wallet.balanceUsagePercentage;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              translate('levelLabel'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(0.3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: percentage > 0.8 
                    ? Colors.yellow.withOpacity(0.9)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(WalletProvider walletProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: MyColors.whiteColor,
                size: 24,
              ),
            ),
            hSizedBox,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ParagraphText(
                  translate('myWallet'),
                  color: MyColors.whiteColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                if (walletProvider.wallet?.isActive == true)
                  ParagraphText(
                    translate('activeStatus'),
                    color: MyColors.whiteColor.withOpacity(0.8),
                    fontSize: 12,
                  ),
              ],
            ),
          ],
        ),
        _buildStatusIndicator(walletProvider),
      ],
    );
  }

  Widget _buildBalanceDisplay(WalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ParagraphText(
          translate('walletBalanceLabel'),
          color: MyColors.textSecondary,
          fontSize: 16,
        ),
        vSizedBox05,
        MainHeadingText(
          walletProvider.formattedBalance,
          color: MyColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }

  Widget _buildBalanceBar(Wallet wallet) {
    double percentage = wallet.balanceUsagePercentage;
    
    return Container(
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.white.withOpacity(0.3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percentage,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: percentage > 0.8 
                ? MyColors.warning
                : MyColors.success,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(WalletProvider walletProvider) {
    Color statusColor;
    IconData statusIcon;
    
    if (walletProvider.isLoading) {
      statusColor = MyColors.whiteColor;
      statusIcon = Icons.sync;
    } else if (walletProvider.hasError) {
      statusColor = MyColors.error;
      statusIcon = Icons.error;
    } else if (walletProvider.hasLowBalance) {
      statusColor = MyColors.warning;
      statusIcon = Icons.battery_2_bar;
    } else {
      statusColor = MyColors.success;
      statusIcon = Icons.check_circle;
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        statusIcon,
        color: statusColor,
        size: 16,
      ),
    );
  }

  Widget _buildLowBalanceAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColors.warning.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MyColors.warning.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: MyColors.warning,
            size: 20,
          ),
          hSizedBox,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ParagraphText(
                  translate('lowBalanceAlert'),
                  color: MyColors.whiteColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                ParagraphText(
                  translate('rememberToRecharge'),
                  color: MyColors.whiteColor.withOpacity(0.9),
                  fontSize: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(WalletProvider walletProvider) {
    String message = '';
    if (walletProvider.isCrediting) {
      message = translate('creditInProgress');
    } else if (walletProvider.isDebiting) {
      message = translate('paymentInProgressLabel');
    } else if (walletProvider.isLoading) {
      message = translate('loadingText');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(MyColors.whiteColor),
            ),
          ),
          hSizedBox,
          ParagraphText(
            message,
            color: MyColors.whiteColor,
            fontSize: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(WalletProvider walletProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MyColors.primaryColor,
                    MyColors.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: MyColors.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: walletProvider.isProcessing ? null : widget.onCreditTap,
                  child: Center(
                    child: Text(
                      translate('creditWallet'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bouton historique - masqué temporairement si onHistoryTap est null
          if (widget.onHistoryTap != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: MyColors.cardThemeColor(),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MyColors.borderThemeColor(),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onHistoryTap,
                    child: Center(
                      child: Text(
                        translate('historyLabel'),
                        style: TextStyle(
                          color: MyColors.blackThemeColor(),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  LinearGradient _buildGradient(Wallet? wallet) {
    if (wallet?.hasLowBalance ?? false) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          MyColors.warning,
          MyColors.warning.withOpacity(0.8),
        ],
      );
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        MyColors.coralPink,
        MyColors.horizonBlue,
      ],
    );
  }
}

/// Widget compact du solde pour utilisation dans d'autres écrans
class WalletBalanceCompact extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showActions;
  
  const WalletBalanceCompact({
    super.key,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        Widget child = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MyColors.coralPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: MyColors.coralPink,
                    size: 20,
                  ),
                ),
                hSizedBox,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ParagraphText(
                        translate('walletLabel'),
                        color: MyColors.textSecondary,
                        fontSize: 12,
                      ),
                      SubHeadingText(
                        walletProvider.formattedBalance,
                        color: MyColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
                if (walletProvider.hasLowBalance)
                  Icon(
                    Icons.warning_amber_rounded,
                    color: MyColors.warning,
                    size: 18,
                  ),
                if (showActions)
                  Icon(
                    Icons.chevron_right,
                    color: MyColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),
          );
          
        return showActions && onTap != null 
            ? GestureDetector(onTap: onTap, child: child)
            : child;
      },
    );
  }
}