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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTab(
            label: TransitStrings.t('mode.course', locale),
            icon: Icons.local_taxi_outlined,
            selected: current == HomeMode.course,
            onTap: () => onChanged(HomeMode.course),
          ),
          _buildTab(
            label: TransitStrings.t('mode.public', locale),
            icon: Icons.directions_bus_outlined,
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
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        elevation: selected ? 1.5 : 0,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? const Color(0xFF1D3557)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF1D3557)
                          : const Color(0xFF6B7280),
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
