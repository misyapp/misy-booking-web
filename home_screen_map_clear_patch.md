// Patch pour home_screen.dart - Nettoyage de la carte lors du retour en arrière

// Dans la fonction onWillPop, il faut ajouter le nettoyage de la carte
// quand l'utilisateur revient à l'écran principal (setYourDestination)

// Remplacer les sections suivantes :

// Section 1: CustomTripType.selectScheduleTime
if (tripProvider.currentStep == CustomTripType.selectScheduleTime && tripProvider.booking == null) {
  navigationProvider.setNavigationBarVisibility(true);
  // Clear la carte quand on revient à l'écran principal
  GoogleMapProvider mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
  mapProvider.polylineCoordinates.clear();
  mapProvider.markers.removeWhere((key, value) => key == "pickup");
  mapProvider.markers.removeWhere((key, value) => key == "drop");
  tripProvider.setScreen(CustomTripType.setYourDestination);
}

// Section 2: CustomTripType.choosePickupDropLocation
else if (tripProvider.currentStep == CustomTripType.choosePickupDropLocation && tripProvider.booking == null) {
  navigationProvider.setNavigationBarVisibility(true);
  // Clear la carte quand on revient à l'écran principal
  GoogleMapProvider mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
  mapProvider.polylineCoordinates.clear();
  mapProvider.markers.removeWhere((key, value) => key == "pickup");
  mapProvider.markers.removeWhere((key, value) => key == "drop");
  tripProvider.setScreen(CustomTripType.setYourDestination);
}
