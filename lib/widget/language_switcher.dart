import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';

/// Dropdown compact FR/MG/EN. À placer dans le menu profil ou en header
/// du panel "Transport en commun" (V1) — bascule la langue uniquement de
/// la nouvelle UI trilingue. Le legacy app reste FR pour l'instant.
class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;

  const LanguageSwitcher({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final current = provider.locale;

    return PopupMenuButton<AppLocale>(
      tooltip: TransitStrings.t('lang.${current.name}', current),
      onSelected: (l) => provider.setLocale(l),
      itemBuilder: (ctx) => [
        for (final l in AppLocale.values)
          PopupMenuItem(
            value: l,
            child: Row(
              children: [
                _flag(l),
                const SizedBox(width: 8),
                Text(TransitStrings.t('lang.${l.name}', current)),
                if (l == current) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: Color(0xFF43A047)),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _flag(current),
            const SizedBox(width: 6),
            Text(
              current.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                TransitStrings.t('lang.${current.name}', current),
                style: const TextStyle(fontSize: 11),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _flag(AppLocale l) {
    final emoji = switch (l) {
      AppLocale.fr => '🇫🇷',
      AppLocale.mg => '🇲🇬',
      AppLocale.en => '🇬🇧',
    };
    return Text(emoji, style: const TextStyle(fontSize: 14));
  }
}
