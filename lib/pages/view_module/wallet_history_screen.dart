import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/wallet_transaction_card.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Écran d'historique des transactions du portefeuille
/// Implémente la pagination, recherche, filtres et export
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // État des filtres
  TransactionType? _selectedType;
  PaymentSource? _selectedSource;
  DateRange? _selectedDateRange;
  double? _minAmount;
  double? _maxAmount;
  String _searchQuery = '';
  
  // États UI
  bool _isSearchActive = false;
  bool _isFilterPanelVisible = false;
  List<WalletTransaction> _filteredTransactions = [];
  bool _isLoadingMore = false;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      if (userData.value?.id != null) {
        // Charger l'historique initial si pas déjà chargé
        if (walletProvider.transactions.isEmpty) {
          walletProvider.loadRecentTransactions(userData.value!.id!);
        }
        _applyFilters();
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreTransactions();
      }
    });
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore) return;
    
    final authProvider = Provider.of<CustomAuthProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (userData.value?.id != null && walletProvider.hasMoreTransactions) {
      setState(() => _isLoadingMore = true);
      
      await walletProvider.loadMoreTransactions(userData.value!.id!);
      _applyFilters();
      
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshTransactions() async {
    final authProvider = Provider.of<CustomAuthProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (userData.value?.id != null) {
      await walletProvider.refreshWallet(userData.value!.id!);
      _applyFilters();
    }
  }

  void _applyFilters() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    List<WalletTransaction> filtered = List.from(walletProvider.transactions);

    // Filtre par type de transaction
    if (_selectedType != null) {
      filtered = filtered.where((t) => t.type == _selectedType).toList();
    }

    // Filtre par source de paiement
    if (_selectedSource != null) {
      filtered = filtered.where((t) => t.source == _selectedSource).toList();
    }

    // Filtre par plage de dates
    if (_selectedDateRange != null) {
      DateTime startDate = _selectedDateRange!.startDate;
      DateTime endDate = _selectedDateRange!.endDate.add(const Duration(days: 1));
      
      filtered = filtered.where((t) => 
        t.timestamp.isAfter(startDate) && t.timestamp.isBefore(endDate)
      ).toList();
    }

    // Filtre par montant
    if (_minAmount != null) {
      filtered = filtered.where((t) => t.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _maxAmount!).toList();
    }

    // Recherche textuelle
    if (_searchQuery.isNotEmpty) {
      String query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) => 
        t.description.toLowerCase().contains(query) ||
        t.formattedDescription.toLowerCase().contains(query) ||
        (t.referenceId?.toLowerCase().contains(query) ?? false) ||
        WalletTransactionHelper.getDisplayNameForSource(t.source).toLowerCase().contains(query)
      ).toList();
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
      }
    });
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelVisible = !_isFilterPanelVisible;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedType = null;
      _selectedSource = null;
      _selectedDateRange = null;
      _minAmount = null;
      _maxAmount = null;
      _searchController.clear();
      _searchQuery = '';
    });
    _applyFilters();
  }

  Future<void> _exportToCSV() async {
    try {
      final transactions = _filteredTransactions;
      if (transactions.isEmpty) {
        showSnackbar(translate('noTransactionToExport'));
        return;
      }

      // Créer le contenu CSV
      StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Date,Type,Source,Montant,Statut,Description,Référence');
      
      for (var transaction in transactions) {
        String date = DateFormat('dd/MM/yyyy HH:mm').format(transaction.timestamp);
        String type = transaction.type == TransactionType.credit ? translate('creditLabel') : translate('debitLabel');
        String source = WalletTransactionHelper.getDisplayNameForSource(transaction.source);
        String amount = '${transaction.amount.toStringAsFixed(0)} MGA';
        String status = _getStatusText(transaction.status);
        String description = transaction.description.replaceAll(',', ';');
        String reference = transaction.referenceId ?? '';
        
        csvContent.writeln('$date,$type,$source,$amount,$status,$description,$reference');
      }

      // Sauvegarder le fichier
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent.toString());

      // Copier le contenu dans le presse-papier
      await Clipboard.setData(ClipboardData(text: csvContent.toString()));

      showSnackbar('${translate('exportSuccess')}: ${transactions.length} ${translate('transactionsCopied')}');
    } catch (e) {
      myCustomPrintStatement('Error exporting CSV: $e');
      showSnackbar('${translate('exportError')}: $e');
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    // Vérifier si la fonctionnalité est activée
    if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
      return Scaffold(
        backgroundColor: MyColors.backgroundThemeColor(),
        appBar: CustomAppBar(
          bgcolor: MyColors.whiteThemeColor(),
          title: translate('transactionHistory'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wallet_outlined,
                  size: 80,
                  color: MyColors.textSecondaryTheme(),
                ),
                const SizedBox(height: 16),
                SubHeadingText(
                  translate('featureTemporarilyUnavailable'),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ParagraphText(
                  translate('historyNotAvailable'),
                  fontSize: 14,
                  color: MyColors.textSecondaryTheme(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MyColors.backgroundThemeColor(),
      appBar: CustomAppBar(
        bgcolor: MyColors.whiteThemeColor(),
        title: translate('transactionHistory'),
        actions: [
          // Bouton de recherche
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _isSearchActive ? Icons.close : Icons.search,
              color: MyColors.textPrimary,
            ),
          ),
          // Bouton de filtre
          IconButton(
            onPressed: _toggleFilterPanel,
            icon: Stack(
              children: [
                Icon(
                  Icons.filter_list,
                  color: MyColors.textPrimary,
                ),
                if (_hasActiveFilters())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MyColors.coralPink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bouton d'export
          IconButton(
            onPressed: _exportToCSV,
            icon: Icon(
              Icons.download,
              color: MyColors.textPrimary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          if (_isSearchActive) _buildSearchBar(),
          
          // Panel de filtres
          if (_isFilterPanelVisible) _buildFilterPanel(),
          
          // Statistiques rapides
          _buildQuickStats(),
          
          // Liste des transactions
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshTransactions,
              child: _buildTransactionsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.borderLight),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: translate('searchTransactions'),
          hintStyle: TextStyle(color: MyColors.textSecondary),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: MyColors.textSecondary),
        ),
        style: TextStyle(color: MyColors.textPrimary),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SubHeadingText(
                translate('filters'),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MyColors.textPrimary,
              ),
              TextButton(
                onPressed: _clearAllFilters,
                child: ParagraphText(
                  translate('clearAllFilters'),
                  color: MyColors.coralPink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          vSizedBox,
          
          // Filtres rapides
          _buildQuickFilters(),
          
          vSizedBox,
          
          // Type de transaction
          _buildTransactionTypeFilter(),
          
          vSizedBox,
          
          // Source de paiement
          _buildPaymentSourceFilter(),
          
          vSizedBox,
          
          // Plage de montant
          _buildAmountRangeFilter(),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParagraphText(
          translate('period'),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MyColors.textPrimary,
        ),
        vSizedBox05,
        Wrap(
          spacing: 8,
          children: [
            _buildQuickDateFilter(translate('today'), DateRange.today()),
            _buildQuickDateFilter(translate('thisWeek'), DateRange.thisWeek()),
            _buildQuickDateFilter(translate('thisMonth'), DateRange.thisMonth()),
            _buildQuickDateFilter(translate('custom'), null, isCustom: true),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickDateFilter(String label, DateRange? range, {bool isCustom = false}) {
    bool isSelected = _selectedDateRange == range;

    return GestureDetector(
      onTap: () {
        if (isCustom) {
          _showDateRangePicker();
        } else {
          setState(() {
            _selectedDateRange = range;
          });
          _applyFilters();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MyColors.coralPink : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyColors.coralPink : MyColors.borderLight,
          ),
        ),
        child: ParagraphText(
          label,
          color: isSelected ? MyColors.whiteColor : MyColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTransactionTypeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParagraphText(
          translate('transactionType'),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MyColors.textPrimary,
        ),
        vSizedBox05,
        Row(
          children: [
            _buildTypeChip(translate('all'), null),
            hSizedBox,
            _buildTypeChip(translate('credits'), TransactionType.credit),
            hSizedBox,
            _buildTypeChip(translate('debits'), TransactionType.debit),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, TransactionType? type) {
    bool isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MyColors.coralPink : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyColors.coralPink : MyColors.borderLight,
          ),
        ),
        child: ParagraphText(
          label,
          color: isSelected ? MyColors.whiteColor : MyColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPaymentSourceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParagraphText(
          translate('paymentSource'),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MyColors.textPrimary,
        ),
        vSizedBox05,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSourceChip(translate('all'), null),
            _buildSourceChip('Airtel Money', PaymentSource.airtelMoney),
            _buildSourceChip('Orange Money', PaymentSource.orangeMoney),
            _buildSourceChip('Telma MVola', PaymentSource.telmaMoney),
            _buildSourceChip(translate('trip'), PaymentSource.tripPayment),
            _buildSourceChip('Bonus', PaymentSource.bonus),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceChip(String label, PaymentSource? source) {
    bool isSelected = _selectedSource == source;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSource = source;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MyColors.coralPink : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyColors.coralPink : MyColors.borderLight,
          ),
        ),
        child: ParagraphText(
          label,
          color: isSelected ? MyColors.whiteColor : MyColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAmountRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParagraphText(
          translate('amountRange'),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MyColors.textPrimary,
        ),
        vSizedBox05,
        Row(
          children: [
            Expanded(
              child: _buildAmountInput('Min', _minAmount, (value) {
                setState(() {
                  _minAmount = value;
                });
                _applyFilters();
              }),
            ),
            hSizedBox,
            ParagraphText('-', color: MyColors.textSecondary),
            hSizedBox,
            Expanded(
              child: _buildAmountInput('Max', _maxAmount, (value) {
                setState(() {
                  _maxAmount = value;
                });
                _applyFilters();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountInput(String hint, double? value, Function(double?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: MyColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (text) {
          if (text.isEmpty) {
            onChanged(null);
          } else {
            double? amount = double.tryParse(text);
            onChanged(amount);
          }
        },
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total',
              '${_filteredTransactions.length}',
              Icons.receipt_long,
              MyColors.horizonBlue,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Crédits',
              '${_filteredTransactions.where((t) => t.type == TransactionType.credit).length}',
              Icons.add_circle_outline,
              MyColors.success,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Débits',
              '${_filteredTransactions.where((t) => t.type == TransactionType.debit).length}',
              Icons.remove_circle_outline,
              MyColors.coralPink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        vSizedBox05,
        ParagraphText(
          value,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MyColors.textPrimary,
        ),
        ParagraphText(
          label,
          fontSize: 12,
          color: MyColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.isLoading && _filteredTransactions.isEmpty) {
          return _buildLoadingState();
        }

        if (_filteredTransactions.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _filteredTransactions.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < _filteredTransactions.length) {
              return WalletTransactionCard(
                transaction: _filteredTransactions[index],
                showDetails: true,
                onTap: () => _showTransactionDetails(_filteredTransactions[index]),
              );
            } else {
              return _buildLoadMoreIndicator();
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: MyColors.coralPink),
          vSizedBox2,
          ParagraphText(
            'Chargement des transactions...',
            color: MyColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: MyColors.textSecondary.withOpacity(0.5),
            ),
            vSizedBox2,
            SubHeadingText(
              _hasActiveFilters() 
                  ? 'Aucune transaction trouvée'
                  : 'Aucune transaction',
              color: MyColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            vSizedBox,
            ParagraphText(
              _hasActiveFilters()
                  ? 'Essayez de modifier vos filtres'
                  : 'Vos transactions apparaîtront ici',
              color: MyColors.textSecondary,
              fontSize: 14,
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters()) ...[
              vSizedBox2,
              TextButton(
                onPressed: _clearAllFilters,
                child: ParagraphText(
                  'Effacer les filtres',
                  color: MyColors.coralPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          color: MyColors.coralPink,
          strokeWidth: 2,
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedType != null ||
           _selectedSource != null ||
           _selectedDateRange != null ||
           _minAmount != null ||
           _maxAmount != null ||
           _searchQuery.isNotEmpty;
  }

  void _showTransactionDetails(WalletTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailsBottomSheet(transaction: transaction),
    );
  }

  void _showDateRangePicker() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: MyColors.coralPink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = DateRange.custom(picked.start, picked.end);
      });
      _applyFilters();
    }
  }
}

/// Classe helper pour les plages de dates
class DateRange {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const DateRange({
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  factory DateRange.today() {
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    return DateRange(
      startDate: start,
      endDate: start,
      label: 'Aujourd\'hui',
    );
  }

  factory DateRange.thisWeek() {
    DateTime now = DateTime.now();
    DateTime start = now.subtract(Duration(days: now.weekday - 1));
    start = DateTime(start.year, start.month, start.day);
    return DateRange(
      startDate: start,
      endDate: now,
      label: 'Cette semaine',
    );
  }

  factory DateRange.thisMonth() {
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, 1);
    return DateRange(
      startDate: start,
      endDate: now,
      label: 'Ce mois',
    );
  }

  factory DateRange.custom(DateTime start, DateTime end) {
    return DateRange(
      startDate: start,
      endDate: end,
      label: 'Personnalisé',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.label == label;
  }

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode ^ label.hashCode;
}

/// Bottom sheet pour afficher les détails d'une transaction
class TransactionDetailsBottomSheet extends StatelessWidget {
  final WalletTransaction transaction;

  const TransactionDetailsBottomSheet({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 50),
      decoration: BoxDecoration(
        color: MyColors.backgroundContrast,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MyColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: transaction.type == TransactionType.credit
                              ? MyColors.success.withOpacity(0.1)
                              : MyColors.coralPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          transaction.type == TransactionType.credit
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: transaction.type == TransactionType.credit
                              ? MyColors.success
                              : MyColors.coralPink,
                          size: 32,
                        ),
                      ),
                      hSizedBox,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SubHeadingText(
                              WalletTransactionHelper.getDisplayNameForSource(transaction.source),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: MyColors.textPrimary,
                            ),
                            ParagraphText(
                              transaction.description,
                              color: MyColors.textSecondary,
                              fontSize: 14,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SubHeadingText(
                            '${transaction.type == TransactionType.credit ? '+' : '-'}${transaction.amount.toStringAsFixed(0)} MGA',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: transaction.type == TransactionType.credit
                                ? MyColors.success
                                : MyColors.coralPink,
                          ),
                          _buildStatusBadge(transaction.status),
                        ],
                      ),
                    ],
                  ),
                  
                  vSizedBox2,
                  Divider(color: MyColors.borderLight),
                  vSizedBox2,
                  
                  // Détails
                  _buildDetailRow('Date', DateFormat('dd/MM/yyyy à HH:mm').format(transaction.timestamp)),
                  _buildDetailRow('Type', transaction.type == TransactionType.credit ? 'Crédit' : 'Débit'),
                  _buildDetailRow('Source', WalletTransactionHelper.getDisplayNameForSource(transaction.source)),
                  
                  if (transaction.referenceId != null && transaction.referenceId!.isNotEmpty)
                    _buildDetailRow('Référence', transaction.referenceId!),
                  
                  if (transaction.tripId != null && transaction.tripId!.isNotEmpty)
                    _buildDetailRow('Trajet', transaction.tripId!),
                  
                  if (transaction.processedAt != null)
                    _buildDetailRow('Traité le', DateFormat('dd/MM/yyyy à HH:mm').format(transaction.processedAt!)),
                  
                  if (transaction.errorMessage != null && transaction.errorMessage!.isNotEmpty)
                    _buildDetailRow('Erreur', transaction.errorMessage!, isError: true),
                  
                  vSizedBox2,
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: MyColors.borderLight),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: ParagraphText(
                            'Fermer',
                            color: MyColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      hSizedBox,
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _shareTransaction(context, transaction),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyColors.coralPink,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: ParagraphText(
                            'Partager',
                            color: MyColors.whiteColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: ParagraphText(
              '$label:',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MyColors.textSecondary,
            ),
          ),
          Expanded(
            child: ParagraphText(
              value,
              fontSize: 14,
              color: isError ? MyColors.error : MyColors.textPrimary,
              fontWeight: isError ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TransactionStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case TransactionStatus.completed:
        color = MyColors.success;
        text = 'Terminé';
        break;
      case TransactionStatus.pending:
        color = MyColors.warning;
        text = 'En attente';
        break;
      case TransactionStatus.processing:
        color = MyColors.horizonBlue;
        text = 'En cours';
        break;
      case TransactionStatus.failed:
        color = MyColors.error;
        text = 'Échec';
        break;
      case TransactionStatus.cancelled:
        color = MyColors.textSecondary;
        text = 'Annulé';
        break;
      case TransactionStatus.refunded:
        color = MyColors.warning;
        text = 'Remboursé';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ParagraphText(
        text,
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _shareTransaction(BuildContext context, WalletTransaction transaction) {
    String shareText = '''
Détail de transaction - Misy

${WalletTransactionHelper.getDisplayNameForSource(transaction.source)}
Montant: ${transaction.type == TransactionType.credit ? '+' : '-'}${transaction.amount.toStringAsFixed(0)} MGA
Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(transaction.timestamp)}
Statut: ${_getStatusText(transaction.status)}
${transaction.referenceId != null ? 'Référence: ${transaction.referenceId}' : ''}

Description: ${transaction.description}
''';

    // Copier dans le presse-papier
    Clipboard.setData(ClipboardData(text: shareText));
    
    showSnackbar('Détails de la transaction copiés dans le presse-papier');
    
    Navigator.pop(context);
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'Terminé';
      case TransactionStatus.pending:
        return 'En attente';
      case TransactionStatus.processing:
        return 'En cours';
      case TransactionStatus.failed:
        return 'Échec';
      case TransactionStatus.cancelled:
        return 'Annulé';
      case TransactionStatus.refunded:
        return 'Remboursé';
    }
  }
}