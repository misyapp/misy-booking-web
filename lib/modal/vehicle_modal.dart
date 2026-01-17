import 'package:rider_ride_hailing_app/functions/print_function.dart';

class VehicleModal {
  String image;
  String marker;
  String name;
  double price;
  double discount;
  int persons;
  int sequence;
  double basePrice;
  String id;
  String shortNote;
  List<String> otherCategory;
  bool active;
  bool selected;
  double waitingTimeFee;
  double perMinCharge;
  bool isFeatured; // Catégorie mise en avant depuis Firebase

  VehicleModal(
      {required this.image,
      required this.name,
      required this.otherCategory,
      required this.price,
      required this.basePrice,
      required this.marker,
      required this.id,
      required this.shortNote,
      required this.sequence,
      required this.perMinCharge,
      required this.active,
      required this.discount,
      required this.selected,
      required this.persons,
      required this.waitingTimeFee,
      this.isFeatured = false});
  factory VehicleModal.fromJson(Map json) {
    myCustomPrintStatement("vehicle json $json");
    return VehicleModal(
        image: json['image'],
        name: json['name'],
        otherCategory: json['otherCategory'] == null
            ? []
            : List.generate(
                json['otherCategory'].length,
                (index) => json['otherCategory'][index],
              ),
        discount: double.parse(json['discount'] ?? "0"),
        price: double.parse(json['perkmcharge']),
        basePrice: double.parse(json['price']),
        perMinCharge: double.parse((json['perMinCharge'] ?? 0).toString()),
        id: json['id'],
        shortNote: json['description'] ?? '',
        active: json['is_active'].toString() == "1" ? true : false,
        selected: false,
        marker: json['marker'],
        persons: int.parse(json['persons'].toString()),
        sequence: int.parse(json['sequence'].toString()),
        waitingTimeFee:
            double.parse(json['waiting_time_rate_per_min'].toString()),
        isFeatured: json['isFeatured'] == true || json['is_featured'] == true);
  }
}
