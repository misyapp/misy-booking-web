# Règles de Développement - Projet Misy

## Vue d'Ensemble

Ce document définit les règles strictes de développement pour le projet Misy. **TOUTES** les contributions doivent respecter ces règles pour maintenir la qualité, la sécurité et la cohérence du code.

## 1. Standards de Code

### Formatage et Style

#### Dart/Flutter
```dart
// ✅ CORRECT - Utiliser le formatage automatique de Dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: const Text('Hello World'),
    );
  }
}

// ❌ INCORRECT - Formatage inconsistant
class MyWidget extends StatelessWidget{
const MyWidget({super.key});
@override
Widget build(BuildContext context){
return Container(padding:EdgeInsets.all(16.0),child:Text('Hello World'));
}
}
```

#### Organisation des Imports
```dart
// ✅ CORRECT - Ordre des imports
import 'package:flutter/material.dart';           // Flutter SDK
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';          // Packages externes
import 'package:firebase_auth/firebase_auth.dart';

import 'package:rider_ride_hailing_app/contants/my_colors.dart';  // Imports locaux
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
```

### Conventions de Nommage

#### Fichiers
- **OBLIGATOIRE**: `snake_case` pour tous les fichiers Dart
- **OBLIGATOIRE**: Suffixes descriptifs
  - Screens: `*_screen.dart`
  - Providers: `*_provider.dart`
  - Services: `*_service.dart`
  - Widgets: `*_widget.dart` ou `custom_*.dart`
  - Models: `*_modal.dart` (respecter la convention existante)

#### Classes
- **OBLIGATOIRE**: `PascalCase`
- **OBLIGATOIRE**: Suffixes appropriés
  ```dart
  // ✅ CORRECT
  class UserAuthProvider extends ChangeNotifier {}
  class CustomButton extends StatelessWidget {}
  class LocationService {}
  
  // ❌ INCORRECT
  class userAuthProvider {}
  class custombutton {}
  class locationservice {}
  ```

#### Variables et Méthodes
- **OBLIGATOIRE**: `camelCase`
- **OBLIGATOIRE**: Noms descriptifs
  ```dart
  // ✅ CORRECT
  bool isUserLoggedIn = false;
  void updateUserProfile() {}
  String getCurrentUserName() {}
  
  // ❌ INCORRECT
  bool flag = false;
  void update() {}
  String get() {}
  ```

### Documentation du Code

#### Commentaires Obligatoires
```dart
// ✅ CORRECT - Documenter les classes publiques
/// Provider gérant l'authentification utilisateur
/// 
/// Gère les opérations de connexion, déconnexion et
/// la persistance de l'état utilisateur
class AuthProvider extends ChangeNotifier {
  /// Connecte l'utilisateur avec email et mot de passe
  /// 
  /// Retourne true si la connexion réussit, false sinon
  Future<bool> login(String email, String password) async {
    // Implémentation...
  }
}
```

#### Commentaires pour la Logique Complexe
```dart
// ✅ CORRECT - Expliquer la logique métier
// Calcul du prix avec réduction basée sur la distance
// Si distance > 10km, appliquer réduction de 10%
// Si distance > 20km, appliquer réduction de 15%
double calculatePrice(double distance, double basePrice) {
  if (distance > 20) {
    return basePrice * 0.85; // 15% de réduction
  } else if (distance > 10) {
    return basePrice * 0.90; // 10% de réduction
  }
  return basePrice;
}
```

## 2. Workflow Git

### Branches

#### Stratégie de Branchage
- **main**: Branch principale (production)
- **develop**: Branch de développement
- **feature/**: Nouvelles fonctionnalités
  - Format: `feature/description-courte`
  - Exemple: `feature/payment-integration`
- **bugfix/**: Corrections de bugs
  - Format: `bugfix/description-courte`
  - Exemple: `bugfix/login-error-handling`
- **hotfix/**: Corrections urgentes en production
  - Format: `hotfix/description-courte`

#### Règles de Branchage
```bash
# ✅ CORRECT - Créer une feature branch
git checkout -b feature/user-profile-update

# ✅ CORRECT - Créer une bugfix branch
git checkout -b bugfix/map-loading-issue

# ❌ INCORRECT - Travailler directement sur main
git checkout main
# Faire des modifications directement
```

### Commits

#### Messages de Commit
**FORMAT OBLIGATOIRE**: `type(scope): description`

Types autorisés:
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `docs`: Documentation
- `style`: Formatage/style (pas de changement de code)
- `refactor`: Refactoring
- `test`: Ajout/modification de tests
- `chore`: Maintenance

```bash
# ✅ CORRECT - Messages de commit
git commit -m "feat(auth): add Google Sign-In integration"
git commit -m "fix(payment): handle network timeout errors"
git commit -m "docs(readme): update installation instructions"
git commit -m "refactor(providers): simplify state management"

# ❌ INCORRECT - Messages de commit
git commit -m "update"
git commit -m "fix bugs"
git commit -m "work in progress"
```

#### Règles de Commit
- **OBLIGATOIRE**: Un commit par changement logique
- **OBLIGATOIRE**: Tests qui passent avant commit
- **INTERDIT**: Commits contenant des credentials ou API keys
- **INTERDIT**: Commits avec code non fonctionnel

### Pull Requests

#### Template de PR
```markdown
## Description
[Description claire des changements]

## Type de changement
- [ ] Bug fix
- [ ] Nouvelle fonctionnalité
- [ ] Breaking change
- [ ] Documentation

## Tests
- [ ] Tests unitaires ajoutés/modifiés
- [ ] Tests d'intégration vérifiés
- [ ] Tests manuels effectués

## Checklist
- [ ] Code formaté avec `dart format`
- [ ] Analyse statique passée (`flutter analyze`)
- [ ] Aucun credential committé
- [ ] Documentation mise à jour
```

## 3. Sécurité

### Gestion des Secrets

#### ❌ INTERDIT - Ne JAMAIS committer
```dart
// ❌ DANGER - Ne jamais faire cela
const String apiKey = "AIzaSyBCV_9MoubJ8OG3DNtmfUAtFC9EPGRbPyQ";
const String password = "mypassword123";
```

#### ✅ OBLIGATOIRE - Utiliser des variables d'environnement
```dart
// ✅ CORRECT - Utiliser des variables d'environnement
const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

// ✅ CORRECT - Ou récupérer depuis AdminSettingsProvider
final apiKey = Provider.of<AdminSettingsProvider>(context).apiKey;
```

### Validation des Entrées

#### ✅ OBLIGATOIRE - Valider toutes les entrées utilisateur
```dart
// ✅ CORRECT - Validation stricte
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email requis';
  }
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!emailRegex.hasMatch(value)) {
    return 'Format email invalide';
  }
  return null;
}
```

### Gestion des Erreurs Sensibles

#### ✅ OBLIGATOIRE - Ne pas exposer d'informations sensibles
```dart
// ✅ CORRECT - Messages d'erreur génériques
try {
  await authenticateUser(email, password);
} catch (e) {
  showSnackbar('Erreur de connexion. Veuillez réessayer.');
  // Log détaillé uniquement en développement
  if (kDebugMode) {
    myCustomLogStatements('Auth error: $e');
  }
}
```

## 4. Performance

### Optimisations Obligatoires

#### Widgets
```dart
// ✅ CORRECT - Utiliser const constructors
const Text('Hello World')

// ✅ CORRECT - Utiliser ListView.builder pour les listes
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ListTile(title: Text(items[index])),
)

// ❌ INCORRECT - Créer des widgets dans build()
Widget build(BuildContext context) {
  final widget = Container(child: Text('Hello')); // ❌ Recréé à chaque build
  return widget;
}
```

#### State Management
```dart
// ✅ CORRECT - Minimiser notifyListeners()
class MyProvider extends ChangeNotifier {
  void updateMultipleValues(String name, int age) {
    _name = name;
    _age = age;
    notifyListeners(); // Une seule notification
  }
}

// ❌ INCORRECT - Notifications multiples
class MyProvider extends ChangeNotifier {
  set name(String value) {
    _name = value;
    notifyListeners(); // ❌ Notification pour chaque changement
  }
  
  set age(int value) {
    _age = value;
    notifyListeners(); // ❌ Notification pour chaque changement
  }
}
```

### Gestion des Ressources

#### ✅ OBLIGATOIRE - Disposer des ressources
```dart
// ✅ CORRECT - Disposal obligatoire
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;
  AnimationController? _controller;

  @override
  void dispose() {
    _subscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
```

## 5. Tests

### Tests Obligatoires

#### Tests Unitaires
```dart
// ✅ OBLIGATOIRE - Tests pour tous les providers
testWidgets('AuthProvider login test', (WidgetTester tester) async {
  final authProvider = AuthProvider();
  
  // Test de connexion réussie
  final result = await authProvider.login('test@example.com', 'password');
  expect(result, true);
  expect(authProvider.isLoggedIn, true);
});
```

#### Tests de Widgets
```dart
// ✅ OBLIGATOIRE - Tests pour les widgets custom
testWidgets('CustomButton tap test', (WidgetTester tester) async {
  bool tapped = false;
  
  await tester.pumpWidget(
    MaterialApp(
      home: CustomButton(
        title: 'Test',
        onTap: () => tapped = true,
      ),
    ),
  );
  
  await tester.tap(find.byType(CustomButton));
  expect(tapped, true);
});
```

### Couverture de Tests

#### ✅ OBJECTIFS OBLIGATOIRES
- **Providers**: 80% minimum
- **Services**: 70% minimum
- **Widgets custom**: 60% minimum
- **Fonctions utilitaires**: 90% minimum

## 6. Architecture

### Patterns Obligatoires

#### State Management
```dart
// ✅ CORRECT - Pattern Provider standard
class CustomProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> performAction() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Logique métier
      await someOperation();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
```

#### Services
```dart
// ✅ CORRECT - Pattern Service
class ApiService {
  static Future<Result<T>> request<T>(
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = parser(json.decode(response.body));
        return Result.success(data);
      }
      return Result.error('HTTP ${response.statusCode}');
    } catch (e) {
      return Result.error('Network error: $e');
    }
  }
}
```

### Séparation des Responsabilités

#### ✅ OBLIGATOIRE - Couches distinctes
```
UI Layer (Widgets/Screens)
    ↓
Business Logic Layer (Providers)
    ↓
Service Layer (Services)
    ↓
Data Layer (Models/Repositories)
```

## 7. Validation Pre-Commit

### Commandes Obligatoires

#### Avant chaque commit
```bash
# ✅ OBLIGATOIRE - Vérifications automatiques
flutter analyze                 # Analyse statique
flutter test                   # Tests
dart format lib/ --set-exit-if-changed  # Formatage
```

#### Script de validation
```bash
#!/bin/bash
# Script .git/hooks/pre-commit

echo "🔍 Analyse du code..."
flutter analyze
if [ $? -ne 0 ]; then
    echo "❌ Erreurs d'analyse détectées"
    exit 1
fi

echo "🧪 Lancement des tests..."
flutter test
if [ $? -ne 0 ]; then
    echo "❌ Tests échoués"
    exit 1
fi

echo "📝 Vérification du formatage..."
dart format lib/ --set-exit-if-changed
if [ $? -ne 0 ]; then
    echo "❌ Code mal formaté"
    exit 1
fi

echo "✅ Validation réussie"
```

## 8. Maintenance

### Révision de Code

#### Critères de Validation
- [ ] Respect des conventions de nommage
- [ ] Tests ajoutés/modifiés
- [ ] Documentation mise à jour
- [ ] Aucun credential committé
- [ ] Performance optimisée
- [ ] Gestion d'erreur appropriée
- [ ] Code formaté correctement

### Refactoring

#### Indicateurs de Refactoring Nécessaire
- Fonctions > 50 lignes
- Classes > 300 lignes
- Duplication de code > 3 fois
- Complexité cyclomatique > 10
- Tests manquants

## 9. Outils et Configuration

### Configuration IDE

#### VS Code (settings.json)
```json
{
  "dart.flutterSdkPath": "path/to/flutter",
  "editor.formatOnSave": true,
  "dart.lineLength": 80,
  "dart.analysisExcludedFolders": ["build"]
}
```

#### Android Studio
- Installer plugins Flutter/Dart
- Configurer formatage automatique
- Activer l'analyse en temps réel

### Outils de Développement

#### ✅ OBLIGATOIRE - Outils à utiliser
- **flutter analyze**: Analyse statique
- **dart format**: Formatage automatique
- **flutter test**: Tests
- **flutter doctor**: Diagnostic environnement

## 10. Non-Conformité

### Sanctions pour Non-Respect

#### Pull Requests
- **Rejet automatique** si règles non respectées
- **Demande de corrections** avant nouveau review
- **Blocage du merge** tant que non conforme

#### Commits
- **Revert** des commits non conformes
- **Squash** des commits multiples pour une feature
- **Amend** pour corriger les messages de commit

## Conclusion

Ces règles sont **NON-NÉGOCIABLES**. Elles garantissent la qualité, la maintenabilité et la sécurité du projet Misy. Tout développeur (humain ou IA) doit s'y conformer strictement.

Pour toute question ou clarification, consulter les documents `CLAUDE.md` et `ARCHITECTURE_TECHNIQUE.md`.