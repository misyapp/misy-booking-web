import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_topup_coordinator_provider.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Section « Portefeuille » de l'espace compte web : solde, recharge mobile
/// money et historique des transactions — sur les providers existants
/// ([WalletProvider], [WalletTopUpCoordinatorProvider]).
///
/// La section n'est instanciée par le shell QUE si le portefeuille est
/// activé (toggle admin `digitalWalletEnabled` + `wallets/{uid}.isActive`) —
/// le masquage total vit dans `account_shell_web.dart`.
class AccountWalletSection extends StatelessWidget {
  const AccountWalletSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portefeuille',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _balanceCard(context, walletProvider),
            const SizedBox(height: 24),
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(child: _transactionsList(walletProvider)),
          ],
        );
      },
    );
  }

  Widget _balanceCard(BuildContext context, WalletProvider walletProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kWebCoral, kWebCoralDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kWebCardRadius),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solde disponible',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                walletProvider.isLoading
                    ? '…'
                    : walletProvider.formattedBalance,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: () => _openTopUpDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Recharger'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kWebCoralDark,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionsList(WalletProvider walletProvider) {
    final transactions = walletProvider.transactions;
    if (walletProvider.isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kWebCoral));
    }
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Aucune transaction pour le moment.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final tx in transactions) _transactionTile(tx),
        if (walletProvider.hasMoreTransactions && userData.value != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton(
                onPressed: () => walletProvider
                    .loadMoreTransactions(userData.value!.id.toString()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kWebCoralDark,
                  side: BorderSide(color: kWebCoral.withOpacity(0.5)),
                ),
                child: const Text('Charger plus'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _transactionTile(WalletTransaction tx) {
    final isCredit = tx.signedAmount >= 0;
    final amountColor = isCredit ? Colors.green.shade700 : Colors.black87;
    final statusColor = tx.isSuccessful
        ? Colors.green.shade700
        : tx.isPending
            ? Colors.orange.shade800
            : Colors.red.shade700;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isCredit ? Colors.green : kWebCoral).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit ? Icons.south_west : Icons.north_east,
                size: 18,
                color: isCredit ? Colors.green.shade700 : kWebCoralDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.formattedDescription,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '−'}${formatAriary(tx.amount)} Ar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.isSuccessful
                      ? 'Réussie'
                      : tx.isPending
                          ? 'En cours'
                          : 'Échouée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openTopUpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _TopUpDialog(),
    );
  }
}

/// Dialog web de recharge : montant prédéfini + opérateur mobile money
/// (+ numéro à débiter pour Airtel/Telma — Orange redirige vers sa page de
/// paiement dans un nouvel onglet).
class _TopUpDialog extends StatefulWidget {
  const _TopUpDialog();

  @override
  State<_TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<_TopUpDialog> {
  static const _amounts = [1000.0, 5000.0, 10000.0, 20000.0, 50000.0, 100000.0];

  double? _amount;
  PaymentMethodType? _method;
  final _phoneController = TextEditingController();
  bool _submitting = false;

  bool get _needsPhone =>
      _method == PaymentMethodType.airtelMoney ||
      _method == PaymentMethodType.telmaMvola;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amount == null || _method == null) {
      showSnackbar('Choisissez un montant et un opérateur.');
      return;
    }
    if (_needsPhone && _phoneController.text.trim().length < 9) {
      showSnackbar('Saisissez le numéro mobile money à débiter.');
      return;
    }
    if (userData.value == null) return;

    setState(() => _submitting = true);
    try {
      final coordinator = Provider.of<WalletTopUpCoordinatorProvider>(
          context,
          listen: false);
      final ok = await coordinator.initiateTopUp(
        paymentMethod: _method!,
        amount: _amount!,
        userId: userData.value!.id.toString(),
        phoneNumber: _needsPhone ? _phoneController.text.trim() : null,
      );
      if (ok) {
        if (mounted) Navigator.of(context).pop();
        showSnackbar(_method == PaymentMethodType.orangeMoney
            ? 'Paiement Orange ouvert dans un nouvel onglet — votre solde se mettra à jour après confirmation.'
            : 'Demande envoyée — validez le paiement sur votre téléphone, votre solde se mettra à jour automatiquement.');
      } else {
        showSnackbar('Le rechargement n\'a pas pu être initié.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kWebCardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recharger mon portefeuille',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              const Text('Montant',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in _amounts)
                    ChoiceChip(
                      label: Text('${formatAriary(amount)} Ar'),
                      selected: _amount == amount,
                      selectedColor: kWebCoral.withOpacity(0.12),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _amount == amount
                            ? kWebCoralDark
                            : Colors.grey.shade700,
                      ),
                      side: BorderSide(
                        color: _amount == amount
                            ? kWebCoral
                            : Colors.grey.shade300,
                      ),
                      onSelected: (_) => setState(() => _amount = amount),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Opérateur',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Column(
                children: [
                  _operatorTile(PaymentMethodType.telmaMvola, 'Telma MVola'),
                  _operatorTile(
                      PaymentMethodType.orangeMoney, 'Orange Money'),
                  _operatorTile(
                      PaymentMethodType.airtelMoney, 'Airtel Money'),
                ],
              ),
              if (_needsPhone) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Numéro mobile money à débiter',
                    hintText: '034 12 345 67',
                    filled: true,
                    fillColor: kWebPageBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kWebCoral),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.black54)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kWebCoral,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Recharger'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _operatorTile(PaymentMethodType method, String label) {
    final selected = _method == method;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _method = method),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kWebCoral.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? kWebCoral : Colors.grey.shade300,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: selected ? kWebCoralDark : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
