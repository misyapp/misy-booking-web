import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/modal/user_modal.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';

/// Menu compte web — refonte façon Uber (carte ancrée sous l'avatar avec
/// en-tête nom + note, 3 cartes d'actions rapides, lignes de navigation,
/// bouton de déconnexion plein). Remplace l'ancien [PopupMenuButton] qui
/// listait les langues à plat ; les langues + le thème vivent désormais
/// dans la feuille [showAccountSettingsSheet] (« Paramètres »).
///
/// Le widget est découplé du `home_screen_web` : toutes les navigations
/// passent par des callbacks, et le thème/la langue par les providers
/// globaux ([DarkThemeProvider], [LocaleProvider]).

const Color _kMisyRed = Color(0xFFEF3B30);
const String _kSupportEmail = 'contact@misyapp.com';

/// Palette dérivée de la luminosité courante du thème (clair/sombre) pour
/// que la carte et la feuille soient correctes dans les deux modes.
class _MenuPalette {
  final bool dark;
  const _MenuPalette(this.dark);

  Color get cardBg => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get tileBg => dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F1F3);
  Color get primaryText => dark ? Colors.white : const Color(0xFF121212);
  Color get secondaryText =>
      dark ? Colors.white70 : const Color(0xFF6B6B70);
  Color get iconColor => dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get divider => dark ? Colors.white10 : const Color(0xFFEDEDED);
}

/// Affiche le menu compte ancré en haut à droite, sous l'avatar.
Future<void> showAccountMenu(
  BuildContext context, {
  required UserModal user,
  required AppLocale locale,
  required bool walletEnabled,
  required bool isEditor,
  required VoidCallback onActivity,
  required VoidCallback onWallet,
  required VoidCallback onProfile,
  required VoidCallback onEditor,
  required VoidCallback onSettings,
  required VoidCallback onLogout,
}) {
  final media = MediaQuery.of(context);
  final width = (media.size.width - 28).clamp(240.0, 320.0);
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black.withOpacity(0.08),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (ctx) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(top: media.padding.top + 56, right: 14),
          child: _AccountMenuCard(
            width: width,
            user: user,
            locale: locale,
            walletEnabled: walletEnabled,
            isEditor: isEditor,
            onActivity: onActivity,
            onWallet: onWallet,
            onProfile: onProfile,
            onEditor: onEditor,
            onSettings: onSettings,
            onLogout: onLogout,
          ),
        ),
      );
    },
  );
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
}

class _AccountMenuCard extends StatelessWidget {
  final double width;
  final UserModal user;
  final AppLocale locale;
  final bool walletEnabled;
  final bool isEditor;
  final VoidCallback onActivity;
  final VoidCallback onWallet;
  final VoidCallback onProfile;
  final VoidCallback onEditor;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _AccountMenuCard({
    required this.width,
    required this.user,
    required this.locale,
    required this.walletEnabled,
    required this.isEditor,
    required this.onActivity,
    required this.onWallet,
    required this.onProfile,
    required this.onEditor,
    required this.onSettings,
    required this.onLogout,
  });

  String _t(String key) => TransitStrings.t(key, locale);

  /// Ferme le menu puis exécute l'action (les callbacks naviguent depuis le
  /// contexte de la page, toujours monté).
  void _dismissThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  Future<void> _openSupport(BuildContext context) async {
    Navigator.of(context).pop();
    final uri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      query: 'subject=${Uri.encodeComponent('Aide Misy')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _MenuPalette(dark);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: p.cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.5 : 0.16),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(p),
            const SizedBox(height: 4),
            _buildQuickActions(context, p),
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: p.divider),
            const SizedBox(height: 4),
            _buildRow(
              context,
              p,
              icon: Icons.person_outline,
              label: _t('web.manageAccount'),
              onTap: () => _dismissThen(context, onProfile),
            ),
            if (isEditor) ...[
              Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: p.divider),
              _buildRow(
                context,
                p,
                icon: Icons.edit_road,
                label: _t('web.fieldEditor'),
                color: const Color(0xFF1565C0),
                onTap: () => _dismissThen(context, onEditor),
              ),
            ],
            Divider(
                height: 1, thickness: 1, indent: 56, color: p.divider),
            _buildRow(
              context,
              p,
              icon: Icons.settings_outlined,
              label: _t('web.settings'),
              onTap: () => _dismissThen(context, onSettings),
            ),
            const SizedBox(height: 8),
            _buildLogout(context, p),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_MenuPalette p) {
    final hasImage = user.profileImage.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : _t('web.account'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: p.primaryText,
                    height: 1.1,
                  ),
                ),
                if (user.averageRating > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, size: 15, color: p.primaryText),
                      const SizedBox(width: 4),
                      Text(
                        user.averageRating.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: p.primaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            backgroundColor: p.tileBg,
            backgroundImage: hasImage ? NetworkImage(user.profileImage) : null,
            child: hasImage
                ? null
                : Icon(Icons.person, color: p.secondaryText, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, _MenuPalette p) {
    final actions = <_QuickAction>[
      _QuickAction(Icons.headset_mic_outlined, _t('web.help'),
          () => _openSupport(context)),
      walletEnabled
          ? _QuickAction(Icons.account_balance_wallet_outlined,
              _t('web.wallet'), () => _dismissThen(context, onWallet))
          : _QuickAction(Icons.person_outline, _t('web.account'),
              () => _dismissThen(context, onProfile)),
      _QuickAction(Icons.receipt_long_outlined, _t('web.activity'),
          () => _dismissThen(context, onActivity)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _buildQuickCard(p, actions[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickCard(_MenuPalette p, _QuickAction a) {
    return Material(
      color: p.tileBg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: a.onTap,
        child: SizedBox(
          height: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a.icon, size: 24, color: p.iconColor),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    _MenuPalette p, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? p.iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color ?? p.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context, _MenuPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Material(
        color: p.tileBg,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _dismissThen(context, onLogout),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Text(
              _t('web.signOut'),
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: _kMisyRed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille « Paramètres » : bascule thème clair/sombre + choix de langue.
Future<void> showAccountSettingsSheet(BuildContext context, AppLocale locale) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountSettingsSheet(locale: locale),
  );
}

class _AccountSettingsSheet extends StatelessWidget {
  final AppLocale locale;
  const _AccountSettingsSheet({required this.locale});

  static const Map<AppLocale, String> _languageLabels = {
    AppLocale.fr: 'Français',
    AppLocale.mg: 'Malagasy',
    AppLocale.en: 'English',
    AppLocale.it: 'Italiano',
    AppLocale.pl: 'Polski',
    AppLocale.de: 'Deutsch',
  };

  String _t(String key, AppLocale loc) => TransitStrings.t(key, loc);

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<DarkThemeProvider>().darkTheme;
    final currentLocale = context.watch<LocaleProvider>().locale;
    final p = _MenuPalette(dark);

    return Container(
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  _t('web.settings', currentLocale),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: p.primaryText,
                  ),
                ),
              ),
              // ── Apparence ──────────────────────────────────────────
              _sectionLabel(p, _t('web.appearance', currentLocale)),
              SwitchListTile.adaptive(
                value: dark,
                onChanged: (val) {
                  context.read<DarkThemeProvider>().darkTheme = val;
                  // Persiste le réglage : 0 = clair, 2 = sombre (cf.
                  // DevFestPreferences.getDarkModeSetting au boot).
                  DevFestPreferences().setDarkModeSetting(val ? 2 : 0);
                },
                activeColor: _kMisyRed,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                secondary: Icon(
                  dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  color: p.iconColor,
                ),
                title: Text(
                  _t('web.darkMode', currentLocale),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: p.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Langue ─────────────────────────────────────────────
              _sectionLabel(p, _t('web.language', currentLocale)),
              for (final loc in AppLocale.values)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(Icons.language, color: p.secondaryText),
                  title: Text(
                    _languageLabels[loc] ?? loc.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: loc == currentLocale
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: p.primaryText,
                    ),
                  ),
                  trailing: loc == currentLocale
                      ? const Icon(Icons.check, color: _kMisyRed)
                      : null,
                  onTap: () =>
                      context.read<LocaleProvider>().setLocale(loc),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(_MenuPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: p.secondaryText,
        ),
      ),
    );
  }
}
