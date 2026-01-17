import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';

class PaymentPromoModel {
  final bool isEnabled;
  final Map<String, double> paymentMethodDiscounts;

  const PaymentPromoModel({
    this.isEnabled = false,
    this.paymentMethodDiscounts = const {},
  });

  factory PaymentPromoModel.fromJson(Map<String, dynamic> json) {
    Map<String, double> discounts = {};
    
    if (json['paymentMethodDiscounts'] != null) {
      final dynamic discountsData = json['paymentMethodDiscounts'];
      if (discountsData is Map) {
        discountsData.forEach((key, value) {
          if (key is String && value != null) {
            discounts[key] = (value is num) ? value.toDouble() : 0.0;
          }
        });
      }
    }

    return PaymentPromoModel(
      isEnabled: json['paymentPromoEnabled'] ?? false,
      paymentMethodDiscounts: discounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentPromoEnabled': isEnabled,
      'paymentMethodDiscounts': paymentMethodDiscounts,
    };
  }

  double getDiscountForMethod(PaymentMethodType method) {
    if (!isEnabled) return 0.0;
    
    String methodValue = method.value;
    return paymentMethodDiscounts[methodValue] ?? 0.0;
  }

  bool hasDiscountForMethod(PaymentMethodType method) {
    return getDiscountForMethod(method) > 0;
  }

  List<PaymentMethodType> getMethodsWithDiscount() {
    if (!isEnabled) return [];
    
    List<PaymentMethodType> methods = [];
    for (String methodName in paymentMethodDiscounts.keys) {
      if (paymentMethodDiscounts[methodName]! > 0) {
        PaymentMethodType method = PaymentMethodTypeExtension.fromValue(methodName);
        methods.add(method);
      }
    }
    return methods;
  }

  PaymentMethodType? getBestDiscountMethod() {
    if (!isEnabled || paymentMethodDiscounts.isEmpty) return null;
    
    String? bestMethodName;
    double bestDiscount = 0.0;
    
    paymentMethodDiscounts.forEach((methodName, discount) {
      if (discount > bestDiscount) {
        bestDiscount = discount;
        bestMethodName = methodName;
      }
    });
    
    if (bestMethodName != null) {
      return PaymentMethodTypeExtension.fromValue(bestMethodName!);
    }
    
    return null;
  }

  PaymentPromoModel copyWith({
    bool? isEnabled,
    Map<String, double>? paymentMethodDiscounts,
  }) {
    return PaymentPromoModel(
      isEnabled: isEnabled ?? this.isEnabled,
      paymentMethodDiscounts: paymentMethodDiscounts ?? this.paymentMethodDiscounts,
    );
  }

  @override
  String toString() {
    return 'PaymentPromoModel(isEnabled: $isEnabled, discounts: $paymentMethodDiscounts)';
  }
}