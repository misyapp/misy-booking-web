import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/pages/account_web/sections/account_profile_section.dart';
import 'package:rider_ride_hailing_app/pages/account_web/sections/account_trips_section.dart';
import 'package:rider_ride_hailing_app/pages/account_web/sections/account_wallet_section.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/wallet_provider.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';

/// Sections de l'espace compte. Passées en `arguments` de la route
/// `/account` (ex. `pushNamed('/account', arguments: AccountSection.profile)`).
enum AccountSection { trips, wallet, profile }

/// Coquille de l'espace compte web (route `/account`) : topbar + navigation
/// latérale (≥900px) ou chips horizontales (mobile), contenu en IndexedStack.
///
/// Les données viennent des providers existants : [TripProvider] (listes de
/// courses) et [WalletProvider] (solde/transactions). Le portefeuille est
/// **entièrement masqué** si désactivé côté admin (`digitalWalletEnabled`)
/// ou si `wallets/{uid}.isActive == false` — pas de grisage, aucune mention.
class AccountShellWeb extends StatefulWidget {
  const AccountShellWeb({super.key});

  @override
  State<AccountShellWeb> createState() => _AccountShellWebState();
}

class _AccountShellWebState extends State<AccountShellWeb> {
  AccountSection _section = AccountSection.trips;
  bool _sectionInitialized = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _guardAndLoad());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sectionInitialized) {
      _sectionInitialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is AccountSection) {
        _section = args;
      } else if (kIsWeb) {
        // Deep-link depuis le menu compte de misy.app (?section=…).
        switch (Uri.base.queryParameters['section']) {
          case 'profile':
            _section = AccountSection.profile;
            break;
          case 'wallet':
            _section = AccountSection.wallet;
            break;
          case 'trips':
            _section = AccountSection.trips;
            break;
        }
      }
    }
  }

  /// Garde d'auth : l'espace compte exige un vrai compte (pas le mode
  /// invité anonyme). Sinon retour à la réservation, où le visiteur peut
  /// ouvrir la carte de connexion.
  void _guardAndLoad() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || userData.value == null) {
      _redirecting = true;
      pushAndRemoveUntil(
        context: context,
        screen: const MainNavigationScreen(),
      );
      return;
    }

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    // Recharge complète : passées + annulées, puis actives/planifiées.
    tripProvider.getMyBookingList();
    tripProvider.getMyCurrentList();

    if (FeatureToggleService.instance.isDigitalWalletEnabled()) {
      Provider.of<WalletProvider>(context, listen: false)
          .initializeWallet(userData.value!.id.toString());
    }
  }

  bool _walletVisible(WalletProvider walletProvider) {
    if (!FeatureToggleService.instance.isDigitalWalletEnabled()) return false;
    // Doc wallet pas encore chargé → on laisse l'entrée visible (le toggle
    // admin global a déjà filtré) ; désactivé par compte → masquage total.
    return walletProvider.wallet?.isActive ?? true;
  }

  void _select(AccountSection section) {
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    if (_redirecting) {
      return const Scaffold(
        backgroundColor: kWebPageBackground,
        body: SizedBox.shrink(),
      );
    }
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final walletVisible = _walletVisible(walletProvider);
        // Si la section wallet est demandée alors qu'elle est masquée
        // (deep-link périmé, désactivation en cours de session) → profil.
        final section = (_section == AccountSection.wallet && !walletVisible)
            ? AccountSection.profile
            : _section;

        final entries = [
          (AccountSection.trips, Icons.route_outlined, 'Mes courses'),
          if (walletVisible)
            (AccountSection.wallet, Icons.account_balance_wallet_outlined,
                'Portefeuille'),
          (AccountSection.profile, Icons.person_outline, 'Profil'),
        ];

        return Scaffold(
          backgroundColor: kWebPageBackground,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return Column(
                children: [
                  _topBar(context),
                  Expanded(
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sidebar(entries, section),
                              Expanded(
                                  child:
                                      _content(section, walletVisible, true)),
                            ],
                          )
                        : Column(
                            children: [
                              _mobileNav(entries, section),
                              Expanded(
                                  child:
                                      _content(section, walletVisible, false)),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ─── Topbar ───────────────────────────────────────────────────────────

  Widget _topBar(BuildContext context) {
    final user = userData.value;
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Image.asset('assets/icons/misy_logo_rose.png', height: 34),
            const SizedBox(width: 20),
            TextButton.icon(
              onPressed: () => pushAndRemoveUntil(
                context: context,
                screen: const MainNavigationScreen(),
              ),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Réserver une course'),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              offset: const Offset(0, 52),
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  Provider.of<CustomAuthProvider>(context, listen: false)
                      .logout(context);
                } else if (value.startsWith('lang.')) {
                  final loc = AppLocale.values.firstWhere(
                    (l) => 'lang.${l.name}' == value,
                    orElse: () => AppLocale.fr,
                  );
                  Provider.of<LocaleProvider>(context, listen: false)
                      .setLocale(loc);
                }
              },
              itemBuilder: (context) => [
                ..._languageItems(context),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Déconnexion', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: kWebPageBackground,
                    backgroundImage: (user != null &&
                            user.profileImage.isNotEmpty)
                        ? NetworkImage(user.profileImage)
                        : null,
                    child: (user == null || user.profileImage.isEmpty)
                        ? Icon(Icons.person,
                            size: 18, color: Colors.grey.shade500)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user?.fullName ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.expand_more,
                      size: 18, color: Colors.black54),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _languageItems(BuildContext context) {
    final current =
        Provider.of<LocaleProvider>(context, listen: false).locale;
    const labels = {
      AppLocale.fr: 'Français',
      AppLocale.mg: 'Malagasy',
      AppLocale.en: 'English',
      AppLocale.it: 'Italiano',
      AppLocale.pl: 'Polski',
      AppLocale.de: 'Deutsch',
    };
    return [
      for (final loc in AppLocale.values)
        PopupMenuItem<String>(
          value: 'lang.${loc.name}',
          child: Row(
            children: [
              Icon(
                loc == current ? Icons.check : Icons.language,
                size: 16,
                color:
                    loc == current ? kWebCoralDark : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Text(
                labels[loc] ?? loc.name,
                style: TextStyle(
                  fontWeight:
                      loc == current ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // ─── Navigation ───────────────────────────────────────────────────────

  Widget _sidebar(
    List<(AccountSection, IconData, String)> entries,
    AccountSection current,
  ) {
    return Container(
      width: 230,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (section, icon, label) in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: section == current
                    ? kWebCoral.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _select(section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: section == current
                              ? kWebCoralDark
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: section == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: section == current
                                ? kWebCoralDark
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mobileNav(
    List<(AccountSection, IconData, String)> entries,
    AccountSection current,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (section, icon, label) in entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 16,
                    color: section == current
                        ? kWebCoralDark
                        : Colors.grey.shade600,
                  ),
                  label: Text(label),
                  selected: section == current,
                  selectedColor: kWebCoral.withOpacity(0.1),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: section == current
                        ? kWebCoralDark
                        : Colors.grey.shade700,
                  ),
                  onSelected: (_) => _select(section),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Contenu ──────────────────────────────────────────────────────────

  Widget _content(
      AccountSection section, bool walletVisible, bool isDesktop) {
    final index = switch (section) {
      AccountSection.trips => 0,
      AccountSection.wallet => 1,
      AccountSection.profile => 2,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 28 : 16),
          child: IndexedStack(
            index: index,
            sizing: StackFit.expand,
            children: [
              const AccountTripsSection(),
              // Jamais instanciée si masquée — aucune requête wallet.
              walletVisible
                  ? const AccountWalletSection()
                  : const SizedBox.shrink(),
              const AccountProfileSection(),
            ],
          ),
        ),
      ),
    );
  }
}
