import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/services/airport_detection_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';

/// Widget de saisie du numéro de vol pour les courses aéroport
class FlightNumberInput extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final bool isPickup; // true = arrivée aéroport, false = départ vers aéroport
  final String? airportName;

  const FlightNumberInput({
    Key? key,
    this.initialValue,
    required this.onChanged,
    required this.isPickup,
    this.airportName,
  }) : super(key: key);

  @override
  State<FlightNumberInput> createState() => _FlightNumberInputState();
}

class _FlightNumberInputState extends State<FlightNumberInput> {
  late TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndNotify(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      // Vide est acceptable (optionnel)
      setState(() => _isValid = true);
      widget.onChanged(null);
    } else if (AirportDetectionService.isValidFlightNumber(trimmed)) {
      // Format valide
      setState(() => _isValid = true);
      final normalized = AirportDetectionService.normalizeFlightNumber(trimmed);
      widget.onChanged(normalized);
    } else {
      // Format invalide
      setState(() => _isValid = false);
      widget.onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = AirportDetectionService.getAirportEmoji(isPickup: widget.isPickup);
    final airportLabel = widget.airportName ?? 'Aéroport';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isValid ? MyColors.primaryColor.withOpacity(0.3) : Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec émoji et titre
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParagraphText(
                      widget.isPickup ? 'Arrivée à l\'aéroport' : 'Départ vers l\'aéroport',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: MyColors.textPrimary,
                    ),
                    ParagraphText(
                      airportLabel,
                      fontSize: 12,
                      color: MyColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Champ de saisie
          TextField(
            controller: _controller,
            onChanged: _validateAndNotify,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Numéro de vol (optionnel)',
              hintText: 'Ex: AF934, KQ255, ET917',
              prefixIcon: Icon(
                Icons.flight,
                color: MyColors.primaryColor,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        _validateAndNotify('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: MyColors.primaryColor.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: MyColors.primaryColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: MyColors.primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              errorText: _isValid ? null : translate('invalidFormat'),
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: MyColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          // Message d'information
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: MyColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ParagraphText(
                  'Votre chauffeur pourra suivre votre vol en temps réel',
                  fontSize: 12,
                  color: MyColors.textSecondary,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget compact d'affichage du numéro de vol (lecture seule)
class FlightNumberDisplay extends StatelessWidget {
  final String flightNumber;
  final bool isPickup;
  final VoidCallback? onTap;

  const FlightNumberDisplay({
    Key? key,
    required this.flightNumber,
    required this.isPickup,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final emoji = AirportDetectionService.getAirportEmoji(isPickup: isPickup);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: MyColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: MyColors.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            ParagraphText(
              'Vol $flightNumber',
              fontWeight: FontWeight.w600,
              color: MyColors.primaryColor,
              fontSize: 14,
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: MyColors.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
