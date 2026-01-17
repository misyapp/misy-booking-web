import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/pricing/pricing_config_v2.dart';
import 'package:rider_ride_hailing_app/models/pricing/traffic_period.dart';
import 'package:rider_ride_hailing_app/models/pricing/price_calculation.dart';
import 'package:rider_ride_hailing_app/models/pricing/promo_code.dart';
import 'package:rider_ride_hailing_app/models/pricing/pricing_scenario.dart';

void main() {
  group('TrafficPeriod Tests', () {
    late TrafficPeriod morningRush;
    late TrafficPeriod eveningRush;
    
    setUp(() {
      morningRush = TrafficPeriod(
        startTime: TimeOfDay(hour: 7, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 59),
        daysOfWeek: [1, 2, 3, 4, 5], // Lun-Ven
      );
      
      eveningRush = TrafficPeriod(
        startTime: TimeOfDay(hour: 16, minute: 0),
        endTime: TimeOfDay(hour: 18, minute: 59),
        daysOfWeek: [1, 2, 3, 4, 5], // Lun-Ven
      );
    });
    
    test('should detect traffic time correctly', () {
      // Lundi 8h30 - dans période matinale
      final mondayMorning = DateTime(2025, 1, 6, 8, 30);
      expect(morningRush.isTrafficTime(mondayMorning), isTrue);
      
      // Lundi 17h30 - dans période soirée
      final mondayEvening = DateTime(2025, 1, 6, 17, 30);
      expect(eveningRush.isTrafficTime(mondayEvening), isTrue);
      
      // Samedi 8h30 - weekend, pas d'embouteillages
      final saturdayMorning = DateTime(2025, 1, 4, 8, 30);
      expect(morningRush.isTrafficTime(saturdayMorning), isFalse);
      
      // Lundi 14h00 - hors créneaux
      final mondayAfternoon = DateTime(2025, 1, 6, 14, 0);
      expect(morningRush.isTrafficTime(mondayAfternoon), isFalse);
      expect(eveningRush.isTrafficTime(mondayAfternoon), isFalse);
    });
    
    test('should handle edge cases for time detection', () {
      // Exactement à l'heure de début
      final exactStart = DateTime(2025, 1, 6, 7, 0);
      expect(morningRush.isTrafficTime(exactStart), isTrue);
      
      // Exactement à l'heure de fin
      final exactEnd = DateTime(2025, 1, 6, 9, 59);
      expect(morningRush.isTrafficTime(exactEnd), isTrue);
      
      // Une minute avant le début
      final beforeStart = DateTime(2025, 1, 6, 6, 59);
      expect(morningRush.isTrafficTime(beforeStart), isFalse);
      
      // Une minute après la fin
      final afterEnd = DateTime(2025, 1, 6, 10, 0);
      expect(morningRush.isTrafficTime(afterEnd), isFalse);
    });
    
    test('should serialize to/from JSON correctly', () {
      final json = morningRush.toJson();
      
      expect(json['startTime'], equals('07:00'));
      expect(json['endTime'], equals('09:59'));
      expect(json['daysOfWeek'], equals([1, 2, 3, 4, 5]));
      
      final restored = TrafficPeriod.fromJson(json);
      expect(restored.startTime.hour, equals(7));
      expect(restored.startTime.minute, equals(0));
      expect(restored.endTime.hour, equals(9));
      expect(restored.endTime.minute, equals(59));
      expect(restored.daysOfWeek, equals([1, 2, 3, 4, 5]));
    });
    
    test('should validate correctly', () {
      expect(morningRush.isValid(), isTrue);
      
      // Période invalide : fin avant début
      final invalidPeriod = TrafficPeriod(
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 0),
        daysOfWeek: [1, 2, 3],
      );
      expect(invalidPeriod.isValid(), isFalse);
      
      // Jours invalides
      final invalidDays = TrafficPeriod(
        startTime: TimeOfDay(hour: 7, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 0),
        daysOfWeek: [0, 8], // Jours inexistants
      );
      expect(invalidDays.isValid(), isFalse);
      
      // Pas de jours
      final noDays = TrafficPeriod(
        startTime: TimeOfDay(hour: 7, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 0),
        daysOfWeek: [],
      );
      expect(noDays.isValid(), isFalse);
    });
    
    test('should display correctly', () {
      final display = morningRush.toString();
      expect(display, contains('07:00'));
      expect(display, contains('09:59'));
      expect(display, contains('Lun'));
      expect(display, contains('Ven'));
    });
  });
  
  group('PricingConfigV2 Tests', () {
    late PricingConfigV2 defaultConfig;
    
    setUp(() {
      defaultConfig = PricingConfigV2.defaultConfig();
    });
    
    test('should create valid default configuration', () {
      expect(defaultConfig.isValid(), isTrue);
      expect(defaultConfig.version, equals("2.0"));
      expect(defaultConfig.enableNewPricingSystem, isFalse);
      
      // Vérifier les prix plancher
      expect(defaultConfig.floorPrices['taxi_moto'], equals(6000.0));
      expect(defaultConfig.floorPrices['classic'], equals(8000.0));
      expect(defaultConfig.floorPrices['confort'], equals(11000.0));
      expect(defaultConfig.floorPrices['4x4'], equals(13000.0));
      expect(defaultConfig.floorPrices['van'], equals(15000.0));
      
      // Vérifier les prix au km
      expect(defaultConfig.pricePerKm['taxi_moto'], equals(2000.0));
      expect(defaultConfig.pricePerKm['classic'], equals(2750.0));
      
      // Vérifier les seuils
      expect(defaultConfig.floorPriceThreshold, equals(3.0));
      expect(defaultConfig.longTripThreshold, equals(15.0));
      expect(defaultConfig.trafficMultiplier, equals(1.4));
      expect(defaultConfig.longTripMultiplier, equals(1.2));
    });
    
    test('should get prices by category correctly', () {
      expect(defaultConfig.getFloorPrice('classic'), equals(8000.0));
      expect(defaultConfig.getPricePerKm('classic'), equals(2750.0));
      expect(defaultConfig.getReservationSurcharge('classic'), equals(5000.0));
      
      // Catégorie inexistante
      expect(defaultConfig.getFloorPrice('inexistant'), equals(0.0));
    });
    
    test('should detect traffic time correctly', () {
      // Lundi 8h30 - embouteillages
      final mondayMorning = DateTime(2025, 1, 6, 8, 30);
      expect(defaultConfig.isTrafficTime(mondayMorning), isTrue);
      
      // Samedi 8h30 - pas d'embouteillages
      final saturdayMorning = DateTime(2025, 1, 4, 8, 30);
      expect(defaultConfig.isTrafficTime(saturdayMorning), isFalse);
    });
    
    test('should validate supported categories', () {
      expect(defaultConfig.isCategorySupported('classic'), isTrue);
      expect(defaultConfig.isCategorySupported('taxi_moto'), isTrue);
      expect(defaultConfig.isCategorySupported('inexistant'), isFalse);
      
      expect(defaultConfig.supportedCategories.length, equals(5));
    });
    
    test('should serialize to/from JSON correctly', () {
      final json = defaultConfig.toJson();
      
      expect(json['version'], equals("2.0"));
      expect(json['enableNewPricingSystem'], isFalse);
      expect(json['floorPrices']['classic'], equals(8000.0));
      expect(json['trafficPeriods'], hasLength(2));
      
      final restored = PricingConfigV2.fromJson(json);
      expect(restored.version, equals(defaultConfig.version));
      expect(restored.enableNewPricingSystem, equals(defaultConfig.enableNewPricingSystem));
      expect(restored.floorPrices['classic'], equals(defaultConfig.floorPrices['classic']));
      expect(restored.trafficPeriods.length, equals(defaultConfig.trafficPeriods.length));
    });
    
    test('should handle invalid JSON gracefully', () {
      // JSON vide - doit utiliser les valeurs par défaut
      final fromEmpty = PricingConfigV2.fromJson({});
      expect(fromEmpty.isValid(), isTrue);
      expect(fromEmpty.version, equals("2.0"));
      
      // JSON avec données manquantes
      final incomplete = PricingConfigV2.fromJson({
        'version': '2.1',
        'floorPrices': {'classic': 9000.0},
      });
      expect(incomplete.version, equals('2.1'));
      expect(incomplete.floorPrices['classic'], equals(9000.0));
      expect(incomplete.floorPrices['taxi_moto'], equals(6000.0)); // Valeur par défaut
    });
    
    test('should copy with modifications correctly', () {
      final modified = defaultConfig.copyWith(
        enableNewPricingSystem: true,
        floorPriceThreshold: 4.0,
      );
      
      expect(modified.enableNewPricingSystem, isTrue);
      expect(modified.floorPriceThreshold, equals(4.0));
      expect(modified.version, equals(defaultConfig.version)); // Inchangé
      expect(modified.floorPrices['classic'], equals(defaultConfig.floorPrices['classic'])); // Inchangé
    });
    
    test('should validate configuration correctly', () {
      expect(defaultConfig.isValid(), isTrue);
      
      // Configuration avec prix négatifs
      final invalidPrices = defaultConfig.copyWith(
        floorPrices: {'classic': -1000.0},
      );
      expect(invalidPrices.isValid(), isFalse);
      
      // Configuration avec seuils incohérents  
      final invalidThresholds = defaultConfig.copyWith(
        floorPriceThreshold: 20.0, // Plus grand que longTripThreshold (15.0)
      );
      expect(invalidThresholds.isValid(), isFalse);
      
      // Configuration avec multiplicateurs invalides
      final invalidMultipliers = defaultConfig.copyWith(
        trafficMultiplier: 0.5, // Doit être > 1.0
      );
      expect(invalidMultipliers.isValid(), isFalse);
    });
  });
  
  group('PriceCalculation Tests', () {
    test('should create V2 calculation correctly', () {
      final calculation = PriceCalculation.v2(
        vehicleCategory: 'classic',
        distance: 10.0,
        isScheduled: true,
        basePrice: 27500.0,
        trafficSurcharge: 11000.0,
        reservationSurcharge: 5000.0,
        promoDiscount: 2000.0,
        finalPrice: 41500.0,
      );
      
      expect(calculation.basePrice, equals(27500.0));
      expect(calculation.trafficSurcharge, equals(11000.0));
      expect(calculation.reservationSurcharge, equals(5000.0));
      expect(calculation.promoDiscount, equals(2000.0));
      expect(calculation.finalPrice, equals(41500.0));
      expect(calculation.isV2Calculation, isTrue);
      expect(calculation.vehicleCategory, equals('classic'));
      expect(calculation.distance, equals(10.0));
      expect(calculation.isScheduled, isTrue);
    });
    
    test('should create V1 calculation correctly', () {
      final calculation = PriceCalculation.v1(
        vehicleCategory: 'classic',
        distance: 10.0,
        isScheduled: false,
        finalPrice: 25000.0,
      );
      
      expect(calculation.basePrice, equals(25000.0));
      expect(calculation.trafficSurcharge, equals(0.0));
      expect(calculation.reservationSurcharge, equals(0.0));
      expect(calculation.promoDiscount, equals(0.0));
      expect(calculation.finalPrice, equals(25000.0));
      expect(calculation.isV2Calculation, isFalse);
      expect(calculation.pricingVersion, equals("v1.0"));
    });
    
    test('should calculate properties correctly', () {
      final calculation = PriceCalculation.v2(
        vehicleCategory: 'classic',
        distance: 10.0,
        isScheduled: true,
        basePrice: 27500.0,
        trafficSurcharge: 11000.0,
        reservationSurcharge: 5000.0,
        promoDiscount: 2000.0,
        finalPrice: 41500.0,
      );
      
      expect(calculation.totalSurcharges, equals(16000.0)); // 11000 + 5000
      expect(calculation.netPrice, equals(41500.0)); // 27500 + 16000 - 2000
      expect(calculation.hasTrafficSurcharge, isTrue);
      expect(calculation.hasReservationSurcharge, isTrue);
      expect(calculation.hasPromoDiscount, isTrue);
    });
    
    test('should format prices correctly', () {
      final calculation = PriceCalculation.v2(
        vehicleCategory: 'classic',
        distance: 10.0,
        isScheduled: true,
        basePrice: 27500.0,
        trafficSurcharge: 11000.0,
        reservationSurcharge: 5000.0,
        promoDiscount: 2000.0,
        finalPrice: 41500.0,
      );
      
      expect(calculation.formattedFinalPrice, equals('41500 MGA'));
      
      final breakdown = calculation.formattedBreakdown;
      expect(breakdown, contains('Prix de base : 27500 MGA'));
      expect(breakdown, contains('Majoration embouteillages : +11000 MGA'));
      expect(breakdown, contains('Surcoût réservation : +5000 MGA'));
      expect(breakdown, contains('Réduction promo : -2000 MGA'));
      expect(breakdown, contains('Prix final : 41500 MGA'));
    });
    
    test('should serialize to/from JSON correctly', () {
      final calculation = PriceCalculation.v2(
        vehicleCategory: 'classic',
        distance: 10.0,
        isScheduled: true,  
        basePrice: 27500.0,
        trafficSurcharge: 11000.0,
        reservationSurcharge: 5000.0,
        promoDiscount: 2000.0,
        finalPrice: 41500.0,
      );
      
      final json = calculation.toJson();
      expect(json['basePrice'], equals(27500.0));
      expect(json['pricingVersion'], equals("v2.0"));
      expect(json['vehicleCategory'], equals('classic'));
      
      final restored = PriceCalculation.fromJson(json);
      expect(restored.basePrice, equals(calculation.basePrice));
      expect(restored.finalPrice, equals(calculation.finalPrice));
      expect(restored.vehicleCategory, equals(calculation.vehicleCategory));
    });
    
    test('should validate correctly', () {
      final validCalculation = PriceCalculation.v2(
        vehicleCategory: 'classic',
        distance: 10.0,
        isScheduled: false,
        basePrice: 27500.0,
        trafficSurcharge: 0.0,
        reservationSurcharge: 0.0,
        promoDiscount: 0.0,
        finalPrice: 27500.0,
      );
      expect(validCalculation.isValid(), isTrue);
      
      // Prix négatifs
      final negativePrice = validCalculation.copyWith(basePrice: -1000.0);
      expect(negativePrice.isValid(), isFalse);
      
      // Distance invalide
      final invalidDistance = validCalculation.copyWith(distance: -5.0);
      expect(invalidDistance.isValid(), isFalse);
      
      // Catégorie invalide
      final invalidCategory = validCalculation.copyWith(vehicleCategory: 'inexistant');
      expect(invalidCategory.isValid(), isFalse);
    });
  });
  
  group('PromoCode Tests', () {
    test('should create percentage promo code correctly', () {
      final promoCode = PromoCode(
        code: "WELCOME10",
        type: PromoType.percentage,
        value: 10.0,
        validUntil: DateTime(2025, 12, 31),
        minAmount: 5000.0,
      );
      
      expect(promoCode.code, equals("WELCOME10"));
      expect(promoCode.type, equals(PromoType.percentage));
      expect(promoCode.value, equals(10.0));
      expect(promoCode.description, equals('10% de réduction'));
    });
    
    test('should create fixed amount promo code correctly', () {
      final promoCode = PromoCode(
        code: "SAVE5000",
        type: PromoType.fixedAmount,
        value: 5000.0,
      );
      
      expect(promoCode.description, equals('5000 MGA de réduction'));
    });
    
    test('should calculate discount correctly', () {
      final percentageCode = PromoCode(
        code: "WELCOME10",
        type: PromoType.percentage,
        value: 10.0,
      );
      
      final fixedCode = PromoCode(
        code: "SAVE5000",
        type: PromoType.fixedAmount,
        value: 5000.0,
      );
      
      // Test pourcentage
      expect(percentageCode.calculateDiscount(25000, 'classic'), equals(2500.0));
      
      // Test montant fixe  
      expect(fixedCode.calculateDiscount(25000, 'classic'), equals(5000.0));
      
      // Réduction ne peut pas dépasser le prix
      expect(fixedCode.calculateDiscount(3000, 'classic'), equals(3000.0));
    });
    
    test('should validate expiration correctly', () {
      final expiredCode = PromoCode(
        code: "EXPIRED",
        type: PromoType.percentage,
        value: 10.0,
        validUntil: DateTime(2020, 1, 1), // Expiré
      );
      
      final validCode = PromoCode(
        code: "VALID",
        type: PromoType.percentage,
        value: 10.0,
        validUntil: DateTime(2030, 1, 1), // Valide
      );
      
      expect(expiredCode.isExpired, isTrue);
      expect(validCode.isExpired, isFalse);
      
      expect(expiredCode.isValid(10000, 'classic'), isFalse);
      expect(validCode.isValid(10000, 'classic'), isTrue);
    });
    
    test('should validate minimum amount correctly', () {
      final codeWithMin = PromoCode(
        code: "MIN10000",
        type: PromoType.percentage,
        value: 10.0,
        minAmount: 10000.0,
      );
      
      expect(codeWithMin.isValid(15000, 'classic'), isTrue);
      expect(codeWithMin.isValid(5000, 'classic'), isFalse);
    });
    
    test('should validate category restrictions correctly', () {
      final restrictedCode = PromoCode(
        code: "CLASSIC_ONLY",
        type: PromoType.percentage,
        value: 10.0,
        validCategories: ['classic', 'confort'],
      );
      
      expect(restrictedCode.isValid(10000, 'classic'), isTrue);
      expect(restrictedCode.isValid(10000, 'confort'), isTrue);
      expect(restrictedCode.isValid(10000, 'taxi_moto'), isFalse);
    });
    
    test('should handle usage limits correctly', () {
      final limitedCode = PromoCode(
        code: "LIMITED",
        type: PromoType.percentage,
        value: 10.0,
        maxUses: 5,
        currentUses: 4,
      );
      
      expect(limitedCode.remainingUses, equals(1));
      expect(limitedCode.isMaxUsesReached, isFalse);
      expect(limitedCode.isValid(10000, 'classic'), isTrue);
      
      final maxedCode = limitedCode.copyWith(currentUses: 5);
      expect(maxedCode.isMaxUsesReached, isTrue);
      expect(maxedCode.isValid(10000, 'classic'), isFalse);
    });
    
    test('should serialize to/from JSON correctly', () {
      final promoCode = PromoCode(
        code: "TEST10",
        type: PromoType.percentage,
        value: 10.0,
        validUntil: DateTime(2025, 12, 31),
        minAmount: 5000.0,
        validCategories: ['classic'],
        maxUses: 100,
        currentUses: 5,
      );
      
      final json = promoCode.toJson();
      expect(json['code'], equals("TEST10"));
      expect(json['type'], equals('percentage'));
      expect(json['value'], equals(10.0));
      
      final restored = PromoCode.fromJson(json);
      expect(restored.code, equals(promoCode.code));
      expect(restored.type, equals(promoCode.type));
      expect(restored.value, equals(promoCode.value));
      expect(restored.validCategories, equals(promoCode.validCategories));
    });
  });
  
  group('PricingScenario Tests', () {
    test('should create immediate scenario correctly', () {
      final scenario = PricingScenario.immediate(
        vehicleCategory: 'classic',
        distance: 10.0,
      );
      
      expect(scenario.vehicleCategory, equals('classic'));
      expect(scenario.distance, equals(10.0));
      expect(scenario.isScheduled, isFalse);
      expect(scenario.requestTime.difference(DateTime.now()).inMinutes.abs(), lessThan(1));
    });
    
    test('should create scheduled scenario correctly', () {
      final futureTime = DateTime.now().add(Duration(hours: 2));
      final scenario = PricingScenario.scheduled(
        vehicleCategory: 'classic',
        distance: 10.0,
        scheduledTime: futureTime,
      );
      
      expect(scenario.isScheduled, isTrue);
      expect(scenario.requestTime, equals(futureTime));
    });
    
    test('should calculate time properties correctly', () {
      // Lundi 14h30
      final weekdayAfternoon = PricingScenario(
        vehicleCategory: 'classic',
        distance: 10.0,
        requestTime: DateTime(2025, 1, 6, 14, 30),
        isScheduled: false,
      );
      
      expect(weekdayAfternoon.isWeekday, isTrue);
      expect(weekdayAfternoon.isWeekend, isFalse);
      expect(weekdayAfternoon.hourOfDay, equals(14));
      expect(weekdayAfternoon.dayOfWeek, equals(1)); // Lundi
      expect(weekdayAfternoon.dayName, equals('Lundi'));
      expect(weekdayAfternoon.isDayTime, isTrue);
      expect(weekdayAfternoon.isNightTime, isFalse);
      
      // Samedi 2h00
      final weekendNight = PricingScenario(
        vehicleCategory: 'classic',
        distance: 10.0,
        requestTime: DateTime(2025, 1, 4, 2, 0),
        isScheduled: false,
      );
      
      expect(weekendNight.isWeekend, isTrue);
      expect(weekendNight.isNightTime, isTrue);
    });
    
    test('should validate correctly', () {
      // Scénario valide
      final validScenario = PricingScenario(
        vehicleCategory: 'classic',
        distance: 10.0,
        requestTime: DateTime.now().add(Duration(hours: 1)),
        isScheduled: false,
      );
      expect(validScenario.isValid(), isTrue);
      
      // Distance invalide
      final invalidDistance = validScenario.copyWith(distance: -5.0);
      expect(invalidDistance.isValid(), isFalse);
      
      // Catégorie invalide
      final invalidCategory = validScenario.copyWith(vehicleCategory: 'inexistant');
      expect(invalidCategory.isValid(), isFalse);
      
      // Date trop ancienne
      final tooOld = validScenario.copyWith(
        requestTime: DateTime.now().subtract(Duration(days: 2)),
      );
      expect(tooOld.isValid(), isFalse);
      
      // Course programmée dans le passé
      final scheduledInPast = validScenario.copyWith(
        isScheduled: true,
        requestTime: DateTime.now().subtract(Duration(minutes: 10)),
      );
      expect(scheduledInPast.isValid(), isFalse);
    });
    
    test('should classify distance correctly', () {
      final shortDistance = PricingScenario.immediate(
        vehicleCategory: 'classic',
        distance: 2.0,
      );
      expect(shortDistance.distanceCategory, equals('Courte distance'));
      
      final mediumDistance = PricingScenario.immediate(
        vehicleCategory: 'classic',
        distance: 8.0,
      );
      expect(mediumDistance.distanceCategory, equals('Distance moyenne'));
      
      final longDistance = PricingScenario.immediate(
        vehicleCategory: 'classic',
        distance: 18.0,
      );
      expect(longDistance.distanceCategory, equals('Longue distance'));
    });
    
    test('should serialize to/from JSON correctly', () {
      final promoCode = PromoCode(
        code: "TEST10",
        type: PromoType.percentage,
        value: 10.0,
      );
      
      final scenario = PricingScenario(
        vehicleCategory: 'classic',
        distance: 10.0,
        requestTime: DateTime(2025, 1, 6, 14, 30),
        isScheduled: true,
        promoCode: promoCode,
      );
      
      final json = scenario.toJson();
      expect(json['vehicleCategory'], equals('classic'));
      expect(json['distance'], equals(10.0));
      expect(json['isScheduled'], isTrue);
      expect(json['promoCode'], isNotNull);
      
      final restored = PricingScenario.fromJson(json);
      expect(restored.vehicleCategory, equals(scenario.vehicleCategory));
      expect(restored.distance, equals(scenario.distance));
      expect(restored.isScheduled, equals(scenario.isScheduled));
      expect(restored.promoCode?.code, equals(promoCode.code));
    });
    
    test('should modify scenarios correctly', () {
      final original = PricingScenario.immediate(
        vehicleCategory: 'classic',
        distance: 10.0,
      );
      
      final promoCode = PromoCode(
        code: "TEST10",
        type: PromoType.percentage,
        value: 10.0,
      );
      
      final withPromo = original.withPromoCode(promoCode);
      expect(withPromo.promoCode?.code, equals("TEST10"));
      
      final withoutPromo = withPromo.withoutPromoCode();
      expect(withoutPromo.promoCode, isNull);
      
      final scheduled = original.asScheduled(DateTime.now().add(Duration(hours: 2)));
      expect(scheduled.isScheduled, isTrue);
      
      final immediate = scheduled.asImmediate();
      expect(immediate.isScheduled, isFalse);
    });
  });
}