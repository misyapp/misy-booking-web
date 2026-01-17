# Documentation du Calcul de Tarif - Application Misy

## Vue d'ensemble

Ce document décrit le fonctionnement actuel du système de calcul de tarif des courses dans l'application Misy. Le calcul se base sur plusieurs composants et prend en compte diverses réductions et frais supplémentaires.

## Composants du Calcul de Tarif

### Variables de Base

Les tarifs sont calculés en utilisant les propriétés suivantes de chaque véhicule (définies dans `VehicleModal`) :

- **`price`** (tarif par km) : Coût par kilomètre parcouru
- **`basePrice`** (tarif de base) : Coût fixe de démarrage
- **`perMinCharge`** (tarif par minute) : Coût par minute de trajet
- **`discount`** (remise véhicule) : Pourcentage de réduction sur le véhicule
- **`waitingTimeFee`** : Tarif d'attente par minute

### Variables de Distance et Temps

- **`totalWilltake.value.distance`** : Distance estimée du trajet en km
- **`totalWilltake.value.time`** : Temps estimé du trajet en minutes

## Formule de Calcul Principale

Le calcul principal est effectué dans la méthode `calculatePrice()` du `TripProvider` (ligne 237-273) :

### 1. Calcul du Prix de Base
```dart
prix_base = (price * distance) + basePrice + (time * perMinCharge)
```

### 2. Application des Réductions

#### Réduction Véhicule
```dart
reduction_vehicule = prix_base * (discount / 100)
prix_apres_reduction = prix_base - reduction_vehicule
```

#### Réduction Taxi Extra (cas spécial)
Pour les taxis avec ID "02b2988097254a04859a" :
```dart
if (vehicleId == "02b2988097254a04859a" && 
    userData.extraDiscount > 0 && 
    globalSettings.enableTaxiExtraDiscount) {
    reduction_extra = userData.extraDiscount
    prix_final = max(0, prix_apres_reduction - reduction_extra)
}
```

### 3. Frais de Réservation
```dart
frais_reservation = rideScheduledTime == null ? 0 : globalSettings.scheduleRideServiceFee
prix_final = prix_final + frais_reservation
```

## Calcul avec Codes Promo

La méthode `calculatePriceAfterCouponApply()` (lignes 275-283) applique les codes promotionnels :

```dart
prix_total = calculatePrice(selectedVehicle)
reduction_promo = prix_total * (promoCode.discountPercent / 100)
reduction_finale = min(reduction_promo, promoCode.maxRideAmount)
prix_final = prix_total - reduction_finale
```

## Interface Utilisateur - Affichage des Prix

Dans `choose_vehicle_sheet.dart` (lignes 285-303), le prix est affiché avec cette logique :

### Prix avec Réductions
Si le véhicule a une réduction ou une réduction taxi extra :
1. **Prix réduit** (affiché en premier) : Prix final avec toutes les réductions
2. **Prix original** (barré) : Prix sans réductions

### Prix Normal
Si aucune réduction : affichage du prix final uniquement

## Détail des Calculs lors de la Création de Réservation

Dans `createBooking()` (lignes 382-592), plusieurs calculs sont effectués :

### Prix Total de la Course
```dart
total_ride_price = (distance * price_per_km) + base_price + (time * price_per_min) + frais_reservation
```

### Prix à Payer (après réductions véhicule)
```dart
ride_price_to_pay = total_ride_price - (total_ride_price * (discount / 100))
```

### Commission Administrative
```dart
ride_price_commission = ride_price_to_pay * (adminCommission / 100)
```

### Revenus Conducteur
```dart
ride_driver_earning = ride_price_to_pay - ride_price_commission
```

## Gestion des Réductions Spéciales

### Réduction Extra Taxi
- Appliquée uniquement sur les véhicules avec ID "02b2988097254a04859a"
- Valeur stockée dans `userData.extraDiscount`
- Contrôlée par `globalSettings.enableTaxiExtraDiscount`

### Réduction Codes Promo
- Pourcentage de réduction : `promoCode.discountPercent`
- Montant maximum : `promoCode.maxRideAmount`
- Application lors de la création de réservation (lignes 524-548)

## Points d'Amélioration Identifiés

1. **Complexité de la formule** : Calculs répétitifs et difficiles à maintenir
2. **Lisibilité du code** : Formules très longues dans l'interface utilisateur
3. **Centralisation** : Logique de calcul dispersée dans plusieurs fichiers
4. **Tests** : Manque de tests unitaires pour valider les calculs

## Fichiers Concernés

- `lib/provider/trip_provider.dart` : Logique principale de calcul
- `lib/bottom_sheet_widget/choose_vehicle_sheet.dart` : Affichage des prix
- `lib/modal/vehicle_modal.dart` : Modèle de données véhicule
- `lib/pages/view_module/booking_detail_screen.dart` : Détails de facturation

---

*Document créé le : 27 juillet 2025*  
*Analysé à partir du code dans la branche : new_design*
