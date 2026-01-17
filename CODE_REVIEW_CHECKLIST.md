# Checklist de Validation du Code - Projet Misy

## Vue d'Ensemble

Cette checklist doit être utilisée pour **TOUTES** les revues de code, qu'elles soient effectuées par des humains ou des agents IA. Elle garantit la qualité, la sécurité et la cohérence du code.

## 🔍 Checklist Pré-Commit

### Vérifications Automatiques

- [ ] `flutter analyze` - Aucune erreur d'analyse statique
- [ ] `flutter test` - Tous les tests passent
- [ ] `dart format lib/` - Code formaté correctement
- [ ] `flutter doctor` - Environnement configuré correctement

### Vérifications Manuelles

#### Sécurité
- [ ] Aucun credential/API key committé
- [ ] Aucun mot de passe en dur
- [ ] Validation des entrées utilisateur
- [ ] Gestion sécurisée des erreurs (pas d'exposition d'infos sensibles)

#### Conventions de Nommage
- [ ] Fichiers en `snake_case` avec suffixes appropriés
- [ ] Classes en `PascalCase`
- [ ] Variables/méthodes en `camelCase`
- [ ] Constantes regroupées dans des classes dédiées

#### Performance
- [ ] Utilisation de `const` constructors
- [ ] Disposal des ressources (StreamSubscriptions, Controllers)
- [ ] Pas de widgets créés dans `build()`
- [ ] Minimisation des appels à `notifyListeners()`

## 📋 Checklist de Code Review

### Architecture et Design Patterns

#### State Management
- [ ] Utilisation correcte du pattern Provider
- [ ] Héritage de `ChangeNotifier` pour les providers
- [ ] Gestion d'état loading/error implémentée
- [ ] Méthodes privées pour la mutation d'état
- [ ] Appel à `notifyListeners()` après changement d'état

#### Services
- [ ] Méthodes statiques pour les services
- [ ] Gestion d'erreur avec try-catch spécifique
- [ ] Retour de `Result<T>` pour les opérations
- [ ] Séparation claire des responsabilités

#### Widgets
- [ ] Widgets réutilisables avec paramètres appropriés
- [ ] Factory constructors pour les variantes communes
- [ ] Utilisation du design system (MyColors, MyDimensions)
- [ ] Validation des paramètres requis

### Code Quality

#### Lisibilité
- [ ] Noms de variables/méthodes explicites
- [ ] Fonctions < 50 lignes
- [ ] Classes < 300 lignes
- [ ] Commentaires pour la logique complexe
- [ ] Organisation cohérente des imports

#### Maintenabilité
- [ ] Pas de duplication de code
- [ ] Utilisation des fonctions utilitaires existantes
- [ ] Respect des patterns établis
- [ ] Documentation des méthodes publiques

#### Robustesse
- [ ] Gestion appropriée des cas d'erreur
- [ ] Validation des paramètres d'entrée
- [ ] Gestion des cas limites
- [ ] Fallbacks pour les opérations critiques

### Tests

#### Couverture
- [ ] Tests unitaires pour les providers (80% minimum)
- [ ] Tests unitaires pour les services (70% minimum)
- [ ] Tests de widgets pour les composants custom (60% minimum)
- [ ] Tests d'intégration pour les flux critiques

#### Qualité des Tests
- [ ] Tests indépendants et reproductibles
- [ ] Utilisation de mocks appropriés
- [ ] Vérification des cas d'erreur
- [ ] Noms de tests descriptifs

### UI/UX

#### Design System
- [ ] Utilisation de `MyColors` pour les couleurs
- [ ] Utilisation de `MyDimensions` pour les dimensions
- [ ] Respect du design Misy V2
- [ ] Composants réutilisables utilisés

#### Accessibilité
- [ ] Semantic labels pour les widgets interactifs
- [ ] Contraste suffisant pour les textes
- [ ] Taille des boutons appropriée (minimum 44px)
- [ ] Navigation au clavier supportée

#### Responsivité
- [ ] Adaptation aux différentes tailles d'écran
- [ ] Gestion de l'orientation portrait/landscape
- [ ] Débordement de contenu géré
- [ ] Utilisation de widgets flexibles

### Intégrations

#### Firebase
- [ ] Utilisation de `FirestoreServices` pour les opérations
- [ ] Gestion des erreurs Firebase spécifiques
- [ ] Règles de sécurité respectées
- [ ] Optimisation des requêtes

#### API Externes
- [ ] Gestion des timeouts réseau
- [ ] Retry logic pour les échecs temporaires
- [ ] Validation des réponses API
- [ ] Gestion de l'état hors ligne

## 🧪 Checklist de Tests

### Tests Unitaires

#### Providers
```dart
// ✅ Test template pour providers
testWidgets('MyProvider loading state test', (WidgetTester tester) async {
  final provider = MyProvider();
  
  // Test état initial
  expect(provider.isLoading, false);
  
  // Test pendant l'opération
  final future = provider.performAction();
  expect(provider.isLoading, true);
  
  // Test après l'opération
  await future;
  expect(provider.isLoading, false);
});
```

#### Services
```dart
// ✅ Test template pour services
test('ApiService success case', () async {
  // Arrange
  final mockClient = MockHttpClient();
  when(mockClient.get(any)).thenAnswer((_) async => 
    http.Response('{"data": "test"}', 200));
  
  // Act
  final result = await ApiService.getData();
  
  // Assert
  expect(result.isSuccess, true);
  expect(result.data, isNotNull);
});
```

### Tests de Widgets

#### Widgets Custom
```dart
// ✅ Test template pour widgets
testWidgets('CustomButton displays text correctly', (WidgetTester tester) async {
  const buttonText = 'Test Button';
  
  await tester.pumpWidget(
    MaterialApp(
      home: CustomButton(title: buttonText),
    ),
  );
  
  expect(find.text(buttonText), findsOneWidget);
});
```

### Tests d'Intégration

#### Flux Critiques
- [ ] Flux d'authentification complet
- [ ] Flux de réservation de trajet
- [ ] Flux de paiement
- [ ] Flux de notification

## 📊 Métriques de Qualité

### Objectifs Minimum

#### Couverture de Code
- **Providers**: 80%
- **Services**: 70%
- **Widgets**: 60%
- **Fonctions utilitaires**: 90%

#### Complexité
- **Complexité cyclomatique**: < 10 par méthode
- **Profondeur d'imbrication**: < 4 niveaux
- **Longueur des méthodes**: < 50 lignes
- **Longueur des classes**: < 300 lignes

#### Performance
- **Temps de build**: < 2 secondes en debug
- **Temps de démarrage**: < 3 secondes
- **Utilisation mémoire**: < 200MB en utilisation normale
- **Framerate**: > 58 FPS en utilisation normale

## 🚨 Points Bloquants

### Rejet Automatique

La PR sera **automatiquement rejetée** si :
- [ ] Tests échouent
- [ ] Analyse statique échoue
- [ ] Credentials committés
- [ ] Code mal formaté
- [ ] Conventions de nommage non respectées

### Corrections Obligatoires

La PR nécessite des **corrections obligatoires** si :
- [ ] Couverture de tests insuffisante
- [ ] Documentation manquante
- [ ] Gestion d'erreur insuffisante
- [ ] Performance dégradée
- [ ] Duplication de code

### Améliorations Recommandées

La PR peut être **améliorée** si :
- [ ] Optimisations possibles
- [ ] Refactoring bénéfique
- [ ] Tests supplémentaires utiles
- [ ] Documentation enrichie

## 📝 Template de Comments

### Commentaires Positifs
```
✅ Excellent pattern de gestion d'état
✅ Bonne gestion des erreurs
✅ Tests complets et bien structurés
✅ Respect parfait des conventions
```

### Commentaires Constructifs
```
💡 Suggestion: Considérer l'utilisation de const constructor ici
💡 Optimisation: Cette méthode pourrait être refactorisée
💡 Sécurité: Valider cette entrée utilisateur
💡 Performance: Éviter de créer ce widget dans build()
```

### Commentaires Bloquants
```
❌ Blocage: Credential committé - doit être supprimé
❌ Blocage: Tests manquants pour cette fonctionnalité
❌ Blocage: Convention de nommage non respectée
❌ Blocage: Gestion d'erreur insuffisante
```

## 🔄 Processus de Review

### Étape 1: Auto-Review
- [ ] Auteur exécute la checklist pré-commit
- [ ] Auteur vérifie les points bloquants
- [ ] Auteur corrige les problèmes évidents

### Étape 2: Review par les Pairs
- [ ] Reviewer utilise cette checklist
- [ ] Reviewer teste manuellement les changements
- [ ] Reviewer vérifie l'impact sur le reste du code

### Étape 3: Validation Finale
- [ ] Tous les points bloquants résolus
- [ ] Tests passent en intégration continue
- [ ] Approbation finale donnée

## 📚 Ressources

### Documentation
- `CLAUDE.md` - Guide pour les agents IA
- `DEVELOPMENT_RULES.md` - Règles de développement
- `ARCHITECTURE_TECHNIQUE.md` - Architecture du projet

### Outils
- Flutter DevTools - Profiling et debug
- VS Code Extensions - Dart, Flutter
- GitHub Actions - CI/CD

## 📈 Amélioration Continue

### Métriques à Suivre
- [ ] Temps de review moyen
- [ ] Nombre de corrections par PR
- [ ] Taux de rejet des PRs
- [ ] Couverture de tests globale

### Révision de la Checklist
Cette checklist doit être révisée :
- [ ] Chaque trimestre
- [ ] Après chaque incident de production
- [ ] Suite aux retours d'expérience
- [ ] Lors de l'ajout de nouvelles technologies

---

**Note**: Cette checklist est un document vivant qui doit être mis à jour régulièrement pour refléter les évolutions du projet et les meilleures pratiques.