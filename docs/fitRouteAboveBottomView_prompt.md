# 🧭 Prompt Claude – Ajustement de l’affichage itinéraire

## 🎯 Contexte

L’application Flutter (Google Maps Flutter) affiche correctement les points de départ et d’arrivée, et obtient déjà la polyline depuis l’API OSRM2.

Actuellement :
- La carte trace bien la route.
- MAIS l’itinéraire n’est pas cadré correctement dans la zone visible.
- Le bas du trajet est souvent caché derrière le **bottom sheet** “Choisissez une course”.

## 🎯 Objectif

Améliorer la logique d’affichage de la carte pour :

1. **Décoder et afficher proprement la polyline** de l’itinéraire.  
2. **Calculer dynamiquement les `LatLngBounds`** à partir des points de la polyline.  
3. **Ajuster automatiquement la caméra (`fitBounds`)** pour inclure tout le trajet.  
4. **Décaler la caméra vers le haut** d’un offset proportionnel à la hauteur du bottom sheet afin que tout le trajet soit visible au-dessus.

---

## ⚙️ Tâches attendues

Créer une fonction Dart utilitaire propre et réutilisable :

```dart
Future<void> fitRouteAboveBottomView({
  required GoogleMapController controller,
  required List<LatLng> routePoints,
  required BuildContext context,
  required double bottomViewRatio, // ex: 0.35
})
```

### Étapes internes de la fonction

1️⃣ Calculer les **bounds** via une boucle sur les points :
```dart
double minLat, maxLat, minLng, maxLng;
```

2️⃣ Appeler :
```dart
controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
```

3️⃣ Calculer la hauteur d’écran :
```dart
final screenHeight = MediaQuery.of(context).size.height;
```

4️⃣ Déduire :
```dart
final bottomOffset = screenHeight * bottomViewRatio / 2;
```

5️⃣ Décaler la caméra vers le haut :
```dart
controller.animateCamera(CameraUpdate.scrollBy(0, bottomOffset));
```

---

## 🧱 Exemple d’appel

```dart
await fitRouteAboveBottomView(
  controller: mapController,
  routePoints: decodedPolylinePoints,
  context: context,
  bottomViewRatio: 0.35,
);
```

---

## ✅ Critères de validation

- L’itinéraire complet est visible sans être caché par le panneau inférieur.  
- Le zoom s’ajuste automatiquement à la longueur du trajet.  
- Aucun dézoom excessif ni décalage latéral.  
- Animation fluide, sans blocage.

---

## 🧩 Optionnel

Prévoir un **padding paramétrable** pour les marges (par défaut 60 px) :

```dart
CameraUpdate.newLatLngBounds(bounds, padding)
```

---

## 📋 Résumé

| Étape | Action | Détail |
|:------|:--------|:-------|
| 1 | Décodage de la polyline | Convertir la polyline en `List<LatLng>` |
| 2 | Calcul des bounds | Déterminer min/max lat/lng |
| 3 | FitBounds | Cadrer tout l’itinéraire |
| 4 | Décalage caméra | Libérer la zone du bas (bottom sheet) |

---
