import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/airport_detection_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';

/// Bottom sheet pour la saisie du numéro de vol lors des réservations planifiées
/// Apparaît uniquement si un aéroport est détecté dans pickup ou drop location
class FlightNumberEntrySheet extends StatefulWidget {
  const FlightNumberEntrySheet({Key? key}) : super(key: key);

  @override
  State<FlightNumberEntrySheet> createState() => _FlightNumberEntrySheetState();
}

class _FlightNumberEntrySheetState extends State<FlightNumberEntrySheet> {
  final TextEditingController _flightNumberController = TextEditingController();
  bool _isValid = true;
  String? _pickupFlightNumber;
  String? _dropFlightNumber;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les valeurs existantes si présentes
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    _pickupFlightNumber = tripProvider.pickLocation?['flightNumber'];
    _dropFlightNumber = tripProvider.dropLocation?['flightNumber'];

    // Utiliser la première valeur disponible pour pré-remplir
    if (_pickupFlightNumber != null) {
      _flightNumberController.text = _pickupFlightNumber!;
    } else if (_dropFlightNumber != null) {
      _flightNumberController.text = _dropFlightNumber!;
    }
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    super.dispose();
  }

  void _validateAndSave(TripProvider tripProvider) {
    final trimmed = _flightNumberController.text.trim();

    if (trimmed.isEmpty) {
      // Vide = acceptable, on continue sans numéro de vol
      _saveAndContinue(tripProvider, null);
    } else if (AirportDetectionService.isValidFlightNumber(trimmed)) {
      // Format valide
      final normalized = AirportDetectionService.normalizeFlightNumber(trimmed);
      _saveAndContinue(tripProvider, normalized);
    } else {
      // Format invalide
      setState(() => _isValid = false);
    }
  }

  void _saveAndContinue(TripProvider tripProvider, String? flightNumber) {
    // Sauvegarder le numéro de vol dans les locations appropriées
    if (tripProvider.pickLocation?['isAirport'] == true) {
      tripProvider.pickLocation!['flightNumber'] = flightNumber;
    }
    if (tripProvider.dropLocation?['isAirport'] == true) {
      tripProvider.dropLocation!['flightNumber'] = flightNumber;
    }

    // Passer à l'étape suivante : choix du véhicule
    tripProvider.setScreen(CustomTripType.chooseVehicle);
    MyGlobalKeys.homePageKey.currentState!.updateBottomSheetHeight();
  }

  void _skip(TripProvider tripProvider) {
    // Continuer sans numéro de vol
    _saveAndContinue(tripProvider, null);
  }

  bool _isPickupAirport(TripProvider tripProvider) {
    return tripProvider.pickLocation?['isAirport'] == true;
  }

  bool _isDropAirport(TripProvider tripProvider) {
    return tripProvider.dropLocation?['isAirport'] == true;
  }

  String _getAirportContext(TripProvider tripProvider) {
    final pickupAirport = _isPickupAirport(tripProvider);
    final dropAirport = _isDropAirport(tripProvider);

    if (pickupAirport && dropAirport) {
      return translate('tripBothAirports');
    } else if (pickupAirport) {
      return translate('tripFromAirport');
    } else if (dropAirport) {
      return translate('tripToAirport');
    }
    return translate('tripAirportGeneric');
  }

  String _getFlightEmoji(TripProvider tripProvider) {
    final pickupAirport = _isPickupAirport(tripProvider);
    final dropAirport = _isDropAirport(tripProvider);

    if (pickupAirport && !dropAirport) {
      return '🛬'; // Arrivée
    } else if (!pickupAirport && dropAirport) {
      return '🛫'; // Départ
    }
    return '✈️'; // Les deux
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateur de tiroir centré
          Center(
            child: GestureDetector(
              onTap: () {
                sheetShowNoti.value = !sheetShowNoti.value;
                MyGlobalKeys.homePageKey.currentState!
                    .updateBottomSheetHeight(milliseconds: 20);
              },
              child: Container(
                height: 6,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: MyColors.colorD9D9D9Theme(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Ligne avec bouton retour et titre
          Row(
            children: [
              // Bouton retour à gauche
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: MyColors.blackThemeColor(),
                  size: 24,
                ),
                onPressed: () {
                  // Retour à l'étape de sélection d'adresse
                  tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
                  MyGlobalKeys.homePageKey.currentState!.updateBottomSheetHeight();
                },
              ),
              // Titre centré avec Expanded
              Expanded(
                child: Center(
                  child: SubHeadingText(
                    translate('flightNumberOptional'),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              // Espace équivalent au bouton pour centrer le titre
              const SizedBox(width: 48),
            ],
          ),

          const SizedBox(height: 4),

          // Trait de séparation gris
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            color: MyColors.colorD9D9D9Theme(),
          ),

          const SizedBox(height: 16),

          // Carte d'information avec émoji
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MyColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MyColors.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  _getFlightEmoji(tripProvider),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ParagraphText(
                        _getAirportContext(tripProvider),
                        fontSize: 13,
                        color: MyColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      ParagraphText(
                        translate('flightNumberInfo'),
                        fontSize: 12,
                        color: MyColors.textSecondary,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Champ de saisie du numéro de vol
          TextField(
            controller: _flightNumberController,
            onChanged: (value) {
              // Réinitialiser l'état de validité et rafraîchir l'UI pour les boutons
              setState(() {
                _isValid = true;
              });
            },
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: translate('flightNumber'),
              hintText: 'Ex: AF934, KQ255, ET917',
              prefixIcon: Icon(
                Icons.flight,
                color: MyColors.primaryColor,
              ),
              suffixIcon: _flightNumberController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _flightNumberController.clear();
                        setState(() => _isValid = true);
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
              errorText: _isValid ? null : translate('invalidFlightFormat'),
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: MyColors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          // Bouton principal - Confirmer le numéro de vol
          RoundEdgedButton(
            verticalMargin: 0,
            width: double.infinity,
            text: translate('confirmFlightNumber'),
            color: _flightNumberController.text.trim().isEmpty
                ? MyColors.colorLightGrey727272  // Grisé si vide
                : MyColors.primaryColor,          // Rouge/orange si rempli
            onTap: _flightNumberController.text.trim().isEmpty
                ? null  // Désactivé si vide
                : () => _validateAndSave(tripProvider),
          ),

          const SizedBox(height: 12),

          // Bouton secondaire - Passer cette étape (toujours visible)
          Center(
            child: TextButton(
              onPressed: () => _skip(tripProvider),
              child: ParagraphText(
                translate('skipThisStep'),
                color: MyColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
