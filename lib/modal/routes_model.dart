class PlacesModal {
  String title;
  String image;

  PlacesModal(
      {required this.title,
        required this.image,
      });
  factory PlacesModal.fromJson(Map json) {
    return PlacesModal(
      title: json['title'],
      image: json['image'],

    );
  }
}