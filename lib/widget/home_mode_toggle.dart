import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';

enum HomeMode { course, publicTransport }

/// Segmented control compact "Course / Transport en commun".
///
/// Posé en haut du panneau gauche. Bascule l'état du mode (sidebar +
/// couches carte) sans toucher à l'instance `GoogleMap`.
class HomeModeToggle extends StatelessWidget {
  final HomeMode current;
  final ValueChanged<HomeMode> onChanged;

  const HomeModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F4),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          _buildTab(
            label: TransitStrings.t('mode.course', locale),
            icon: Icons.local_taxi_rounded,
            selected: current == HomeMode.course,
            onTap: () => onChanged(HomeMode.course),
          ),
          _buildTab(
            label: TransitStrings.t('mode.public', locale),
            icon: Icons.directions_bus_rounded,
            selected: current == HomeMode.publicTransport,
            onTap: () => onChanged(HomeMode.publicTransport),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    // Tab actif : fond plein coral charte Misy, texte/icône blanc.
    // Inactif : transparent, texte navy en peu d'opacité.
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFFFF5357) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        elevation: selected ? 2 : 0,
        shadowColor: const Color(0xFFFF5357).withOpacity(0.35),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF1D3557).withOpacity(0.55),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF1D3557).withOpacity(0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
