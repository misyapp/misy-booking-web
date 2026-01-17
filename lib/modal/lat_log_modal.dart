class LatLngModal {
  double lat;
  double lng;
  LatLngModal({required this.lat, required this.lng});
  factory LatLngModal.fromJson(json) {
    return LatLngModal(lat: json["lat"], lng: json["lng"]);
  }
}