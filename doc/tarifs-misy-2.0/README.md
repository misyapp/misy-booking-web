# Migration Tarifs Misy 2.0 - Plan d'Implémentation

## 🎯 Objectif du Projet

Migration transparente du système de tarification de l'application Misy vers une nouvelle formule de calcul, sans impact visible pour les utilisateurs finaux.

## 📋 Vue d'Ensemble

**Durée totale** : 5 semaines (4 sprints)  
**Stratégie** : Migration progressive avec systèmes parallèles  
**Principe clé** : ⚠️ **AUCUN changement visible côté utilisateur**

## 🔄 Nouvelle Formule de Tarification

### Calcul de Base
- **Distance < 3 km** : Prix plancher par catégorie
- **Distance 3-15 km** : Prix/km linéaire  
- **Distance > 15 km** : Majoration ×1.2 au-delà de 15 km

### Majorations
- **Embouteillages** : ×1.4 (7h-10h et 16h-19h, lun-ven)
- **Réservation** : Surcoût fixe par catégorie
- **Arrondi** : Multiple de 500 MGA le plus proche

## 📁 Structure de Documentation

```
doc/tarifs-misy-2.0/
├── README.md                           # Ce fichier - Vue d'ensemble
├── sprints/
│   ├── SPRINT_1_ARCHITECTURE.md        # Sprint 1 - Fondations backend
│   ├── SPRINT_2_INTEGRATION.md         # Sprint 2 - Intégration système
│   ├── SPRINT_3_VALIDATION.md          # Sprint 3 - Tests et validation
│   └── SPRINT_4_DEPLOIEMENT.md         # Sprint 4 - Rollout progressif
├── specifications/
│   ├── MODELES_DONNEES.md              # Structures de données v2
│   ├── ALGORITHMES_CALCUL.md           # Logique de calcul détaillée
│   └── ARCHITECTURE_TECHNIQUE.md       # Architecture système
└── configuration/
    ├── FIRESTORE_CONFIG.md             # Configuration Firestore
    └── FEATURE_FLAGS.md                # Gestion des flags de migration
```

## 🏃‍♂️ Sprints et Planning

| Sprint | Semaines | Objectif Principal | Statut |
|--------|----------|-------------------|---------|
| **Sprint 1** | 1-2 | Architecture et fondations backend | 📋 Planifié |
| **Sprint 2** | 3 | Intégration et sélecteur de système | 📋 Planifié |
| **Sprint 3** | 4 | Tests et validation en shadow mode | 📋 Planifié |
| **Sprint 4** | 5 | Déploiement progressif et monitoring | 📋 Planifié |

## ⚠️ Contraintes Critiques

### 🚫 Interdictions Absolues
- Afficher des détails de calcul aux utilisateurs
- Modifier l'interface utilisateur existante
- Créer des widgets de comparaison prix visibles
- Changer le flow de réservation
- Ajouter des indicateurs "nouveau système"

### ✅ Exigences de Transparence
- Interface utilisateur exactement identique
- Temps de réponse équivalents
- Aucun changement dans le parcours utilisateur
- Rollback instantané possible via feature flag

## 🛠️ Outils Internes Uniquement

- Dashboard admin de monitoring des prix
- Outils de comparaison v1/v2 pour développeurs
- Métriques de performance système
- Interface de configuration Firestore
- Logs détaillés pour équipe technique

## 🔄 Stratégie de Migration

1. **Développement parallèle** : Nouveau système coexiste avec l'ancien
2. **Feature flag Firestore** : Contrôle du pourcentage d'utilisateurs
3. **Shadow testing** : Validation sans impact utilisateur
4. **Rollout progressif** : 5% → 25% → 75% → 100%
5. **Rollback immédiat** : Retour à l'ancien système en cas de problème

## 📊 Métriques de Succès

- **0% d'impact UX** : Aucun changement visible utilisateur
- **Performance** : Temps de calcul < 200ms
- **Fiabilité** : 99.9% de disponibilité
- **Précision** : Écarts de prix < 5% vs spécifications

## 🚀 Pour Commencer

1. Lire les spécifications détaillées dans `/specifications/`
2. Consulter le sprint actuel dans `/sprints/`
3. Vérifier la configuration Firestore dans `/configuration/`
4. Suivre les tâches définies pour chaque sprint

---

**Responsable technique** : Équipe développement Misy  
**Contact** : Documentation mise à jour le 28 juillet 2025