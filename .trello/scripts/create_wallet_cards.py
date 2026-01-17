#!/usr/bin/env python3
"""Script pour créer les cartes Trello de la refactorisation portefeuille"""

import sys
import os
import json

# Ajouter le répertoire parent au path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from lib.trello_client import TrelloClient

def create_wallet_refactoring_cards():
    """Créer toutes les cartes pour la refactorisation du portefeuille"""
    
    # Initialiser le client Trello
    client = TrelloClient()
    
    # Récupérer les listes
    lists = client.get_lists()
    list_mapping = {lst['name']: lst['id'] for lst in lists}
    
    # Récupérer ou créer le label urgent
    labels = client.get_labels()
    urgent_label = next((l for l in labels if '🔴 Urgent' in l['name']), None)
    if not urgent_label:
        urgent_label = client.create_label('🔴 Urgent', 'red')
    
    # Carte parent
    parent_card = {
        "name": "MISY-004: Refactorisation complète du système de portefeuille",
        "desc": """## Description
Refonte complète du système de portefeuille pour permettre :
- Un wallet intégré avec solde rechargeable
- Plusieurs méthodes de paiement du même type (ex: plusieurs comptes MVola)
- Interface moderne avec cartes de paiement redesignées
- Interactions simplifiées et intuitives

## Contexte
Le système actuel ne permet qu'une seule méthode de paiement par type et manque de modernité. Cette refactorisation apportera plus de flexibilité aux utilisateurs et améliorera significativement l'expérience de paiement.

## Structure de l'implémentation
Cette feature est divisée en 4 phases :

### Phase 1 - Backend & Structure de données (MISY-005 à MISY-008)
- Modélisation Firestore pour wallet et méthodes multiples
- Services de gestion côté client

### Phase 2 - Composants UI (MISY-009 à MISY-012)  
- Wallet avec solde et rechargement
- Cartes de paiement modernisées
- Bottom sheet d'ajout de méthode

### Phase 3 - Interactions (MISY-013 à MISY-015)
- Logique d'interaction directe sur les cartes
- Modal unifié de configuration
- Gestion d'état centralisée

### Phase 4 - Intégration (MISY-016 à MISY-017)
- Assemblage dans la page "Mon portefeuille"
- Validation, sécurité et tests

## Impact estimé
- Augmentation de 30% du taux d'utilisation des paiements digitaux
- Réduction de 50% du temps de configuration de paiement
- Amélioration significative de la satisfaction utilisateur

## Dépendances
Toutes les phases doivent être réalisées dans l'ordre pour assurer la cohérence.""",
        "idList": list_mapping['Backlog'],
        "idLabels": [urgent_label['id']]
    }
    
    # Phase 1 - Backend
    phase1_cards = [
        {
            "name": "MISY-005: Modélisation des données Wallet",
            "desc": """## Description
Concevoir et implémenter la structure de données pour le wallet utilisateur dans Firestore.

## Contexte  
Création d'un système de wallet permettant aux utilisateurs de maintenir un solde rechargeable pour leurs trajets.

## Fichiers concernés
- `lib/models/wallet_model.dart` (nouveau)
- `lib/models/wallet_transaction_model.dart` (nouveau)
- Documentation Firestore à mettre à jour

## Structure de données proposée
```
users/{userId}/wallet
  - balance: number
  - currency: string (MGA)
  - created_at: timestamp
  - updated_at: timestamp
  
users/{userId}/wallet_transactions/{transactionId}
  - amount: number
  - type: string (credit/debit)
  - source: string (recharge/trip/refund)
  - reference: string
  - created_at: timestamp
  - metadata: map
```

## Impact estimé
- Base solide pour toutes les opérations wallet
- Historique complet des transactions
- Scalabilité pour futures évolutions""",
            "idList": list_mapping['À faire']
        },
        {
            "name": "MISY-006: Modélisation méthodes de paiement multiples",
            "desc": """## Description
Adapter la structure de données pour permettre l'ajout de plusieurs méthodes de paiement du même type.

## Contexte
Les utilisateurs veulent pouvoir enregistrer plusieurs comptes mobile money ou cartes bancaires.

## Fichiers concernés
- `lib/models/payment_method_model.dart` (à modifier)
- `lib/provider/payment_method_provider.dart` (à adapter)
- Migration des données existantes

## Structure proposée
```
users/{userId}/payment_methods/{methodId}
  - id: string (auto-generated)
  - type: string (mvola/orange_money/airtel_money/card)
  - display_name: string
  - account_number: string (masqué)
  - is_default: boolean
  - metadata: map (logo, couleur, etc.)
  - created_at: timestamp
```

## Impact estimé
- Flexibilité accrue pour les utilisateurs
- Support de cas d'usage business (plusieurs comptes)
- Migration transparente des données existantes""",
            "idList": list_mapping['À faire']
        },
        {
            "name": "MISY-007: Services de gestion du Wallet",
            "desc": """## Description
Développer les services nécessaires pour gérer les opérations du wallet côté client.

## Contexte
Services Flutter pour interagir avec le wallet Firestore et gérer les opérations courantes.

## Fichiers concernés
- `lib/services/wallet_service.dart` (nouveau)
- `lib/provider/wallet_provider.dart` (nouveau)
- Tests unitaires associés

## Fonctionnalités à implémenter
- `getWalletBalance()` - Consultation solde temps réel
- `rechargeWallet(amount, paymentMethodId)` - Rechargement
- `debitWallet(amount, tripId)` - Débit pour trajet
- `getTransactionHistory()` - Historique des transactions
- `refundToWallet(amount, tripId)` - Remboursement

## Impact estimé
- API claire et réutilisable
- Gestion d'erreurs robuste
- Performance optimisée avec cache local""",
            "idList": list_mapping['À faire']
        },
        {
            "name": "MISY-008: Services CRUD méthodes de paiement",
            "desc": """## Description
Développer les services pour la gestion complète des méthodes de paiement multiples.

## Contexte
Services permettant d'ajouter, modifier, supprimer et gérer plusieurs méthodes de paiement.

## Fichiers concernés
- `lib/services/payment_method_service.dart` (à étendre)
- `lib/provider/payment_method_provider.dart` (à adapter)
- Validateurs et utilitaires

## Fonctionnalités à implémenter
- `addPaymentMethod(type, details)` - Ajout avec validation
- `getPaymentMethods()` - Liste toutes les méthodes
- `updatePaymentMethod(id, details)` - Modification
- `deletePaymentMethod(id)` - Suppression avec vérifications
- `setDefaultPaymentMethod(id)` - Définir par défaut

## Impact estimé
- Gestion complète du cycle de vie
- Validation métier intégrée
- Support multi-méthodes transparent""",
            "idList": list_mapping['À faire']
        }
    ]
    
    # Phase 2 - UI
    phase2_cards = [
        {
            "name": "MISY-009: Composant d'affichage du Wallet",
            "desc": """## Description
Créer l'interface utilisateur pour afficher et gérer le wallet utilisateur.

## Contexte
Interface moderne et intuitive pour consulter le solde et recharger le wallet.

## Fichiers concernés
- `lib/widget/wallet_balance_widget.dart` (nouveau)
- `lib/widget/wallet_recharge_sheet.dart` (nouveau)
- `lib/pages/profile/wallet_section.dart` (nouveau)

## Spécifications UI
- Card avec solde en gros caractères
- Bouton "Recharger" prominent
- Montants de recharge prédéfinis (5000, 10000, 20000 Ar)
- Animation lors des transactions
- Historique accessible via icône

## Impact estimé
- Interface claire et attractive
- Réduction friction pour recharge
- Adoption facilitée du wallet""",
            "idList": list_mapping['Backlog']
        },
        {
            "name": "MISY-010: Redesign cartes de méthodes de paiement",
            "desc": """## Description
Moderniser l'affichage des méthodes de paiement selon les spécifications design.

## Contexte
Les cartes actuelles manquent de modernité et de clarté visuelle.

## Fichiers concernés
- `lib/widget/payment_method_card.dart` (refonte complète)
- `lib/utils/payment_method_formatter.dart` (nouveau)
- Assets pour logos des services

## Spécifications design
- Cartes individuelles avec fond blanc
- Coins arrondis 12-16px
- Ombre douce (elevation: 2)
- Logo du service visible (40x40px)
- Numéro masqué format: 03•• ••• 445
- Radio button Material pour sélection
- Padding: 16px, margin bottom: 12px

## Impact estimé
- Interface moderne et professionnelle
- Meilleure reconnaissance visuelle
- Cohérence avec standards UI actuels""",
            "idList": list_mapping['Backlog']
        },
        {
            "name": "MISY-011: Bottom Sheet d'ajout de méthode",
            "desc": """## Description
Créer l'interface modale pour ajouter de nouvelles méthodes de paiement.

## Contexte
Remplacer la page séparée par un bottom sheet moderne et fluide.

## Fichiers concernés
- `lib/bottom_sheet_widget/add_payment_method_sheet.dart` (nouveau)
- `lib/widget/payment_method_form.dart` (nouveau)
- Formulaires spécifiques par type

## Spécifications techniques
- DraggableScrollableSheet avec snap points
- Backdrop semi-transparent (0.5 opacity)
- Animation d'entrée smooth (300ms)
- Formulaires dynamiques selon le type
- Validation en temps réel
- Keyboard avoiding behavior

## Impact estimé
- Expérience utilisateur fluide
- Réduction des étapes d'ajout
- Meilleure conversion""",
            "idList": list_mapping['Backlog']
        },
        {
            "name": "MISY-012: Bouton d'ajout modernisé",
            "desc": """## Description
Redesigner le bouton "Ajouter un mode de paiement" selon les spécifications.

## Contexte
Le bouton actuel n'est pas assez visible et manque de modernité.

## Fichiers concernés
- `lib/widget/add_payment_button.dart` (nouveau)
- Intégration dans la page portefeuille

## Spécifications design
- Bouton large avec icône "+" à gauche
- Couleur primaire de l'app
- Hauteur: 48px
- Border radius: 8px
- Texte: "Ajouter un mode de paiement"
- Ripple effect au tap
- Positionnement: bas de la liste des cartes

## Impact estimé
- Call-to-action plus visible
- Augmentation taux d'ajout
- Cohérence visuelle""",
            "idList": list_mapping['Backlog']
        }
    ]
    
    # Phase 3 - Interactions
    phase3_cards = [
        {
            "name": "MISY-013: Gestion interactions cartes de paiement",
            "desc": """## Description
Implémenter les nouvelles interactions pour les méthodes de paiement configurées.

## Contexte
Simplifier les interactions en supprimant les icônes redondantes.

## Fichiers concernés
- `lib/widget/payment_method_card.dart` (modifier interactions)
- `lib/pages/profile/payment_methods_page.dart` (adapter)

## Changements à implémenter
- Supprimer icônes corbeille et modification
- Tap sur carte → ouvre configuration
- Long press → sélection rapide par défaut
- Feedback visuel (ripple, elevation)
- État sélectionné visuellement distinct

## Impact estimé
- Interface épurée et moderne
- Interactions plus intuitives
- Réduction cognitive pour l'utilisateur""",
            "idList": list_mapping['Backlog']
        },
        {
            "name": "MISY-014: Modal configuration méthodes existantes",
            "desc": """## Description
Créer l'interface de modification/suppression des méthodes de paiement.

## Contexte
Centraliser toutes les actions dans une seule interface cohérente.

## Fichiers concernés
- `lib/bottom_sheet_widget/payment_method_config_sheet.dart` (nouveau)
- `lib/widget/payment_method_actions.dart` (nouveau)

## Fonctionnalités du modal
- Affichage détails de la méthode
- Switch "Définir par défaut"
- Bouton "Modifier les informations"
- Bouton "Supprimer" (rouge, avec confirmation)
- Design cohérent avec add_payment_sheet

## Impact estimé
- Gestion unifiée des méthodes
- Moins de navigation
- Actions contextuelles claires""",
            "idList": list_mapping['Backlog']
        },
        {
            "name": "MISY-015: Gestion d'état et logique métier",
            "desc": """## Description
Implémenter la logique de gestion d'état pour toutes les fonctionnalités wallet.

## Contexte
Assurer la cohérence des données entre tous les composants.

## Fichiers concernés
- `lib/provider/wallet_provider.dart` (compléter)
- `lib/provider/payment_method_provider.dart` (adapter)
- `lib/utils/wallet_state_manager.dart` (nouveau)

## Points clés à implémenter
- État centralisé avec ChangeNotifier
- Sync temps réel Firestore
- Cache local pour performance
- Gestion états loading/error/success
- Notifications inter-composants
- Rollback en cas d'erreur

## Impact estimé
- Fiabilité des données
- Performance optimale
- Expérience utilisateur cohérente""",
            "idList": list_mapping['Backlog']
        }
    ]
    
    # Phase 4 - Intégration
    phase4_cards = [
        {
            "name": "MISY-016: Intégration page Mon portefeuille",
            "desc": """## Description
Assembler tous les composants dans la page principale et assurer la cohérence.

## Contexte
Intégration finale de toutes les fonctionnalités développées.

## Fichiers concernés
- `lib/pages/profile/my_wallet_page.dart` (refonte)
- `lib/navigation/profile_navigation.dart` (si nécessaire)
- Routing et deep links

## Structure de la page
1. Header avec titre
2. Section Wallet (solde + recharge)
3. Divider
4. Section "Modes de paiement"
5. Liste des cartes de paiement
6. Bouton d'ajout
7. Espacement responsive

## Impact estimé
- Page unifiée et cohérente
- Navigation intuitive
- Performances optimisées""",
            "idList": list_mapping['Backlog']
        },
        {
            "name": "MISY-017: Validation, sécurité et tests",
            "desc": """## Description
Implémenter les validations nécessaires et les mesures de sécurité.

## Contexte
Assurer la robustesse et la sécurité de l'ensemble du système.

## Fichiers concernés
- `lib/validators/payment_validators.dart` (étendre)
- `lib/security/payment_security.dart` (nouveau)
- `test/` (tous les tests unitaires et d'intégration)

## Points de validation
- Format numéros téléphone (10 chiffres, opérateurs)
- Format cartes bancaires (Luhn algorithm)
- Montants min/max pour recharge
- Solde suffisant pour paiement
- Données sensibles jamais en clair
- Logs sécurisés sans PII

## Tests à implémenter
- Tests unitaires tous services
- Tests widgets pour les composants
- Tests d'intégration end-to-end
- Tests de performance
- Tests edge cases

## Impact estimé
- Système robuste et sécurisé
- Confiance utilisateur renforcée
- Conformité standards paiement""",
            "idList": list_mapping['Backlog']
        }
    ]
    
    # Créer toutes les cartes
    created_cards = []
    
    print("🚀 Création des cartes Trello pour la refactorisation du portefeuille...")
    
    # Créer la carte parent
    print("\n📦 Création de la carte parent...")
    parent = client.create_card(**parent_card)
    created_cards.append(parent)
    print(f"✅ {parent_card['name']}")
    
    # Créer les cartes Phase 1
    print("\n📋 Phase 1 - Backend & Structure de données:")
    for card_data in phase1_cards:
        # Ajouter checklist
        card = client.create_card(**card_data)
        
        # Créer la checklist selon le type de carte
        if "MISY-005" in card_data["name"]:
            checklist_items = [
                "Structure Firestore wallet définie",
                "Structure transactions définie", 
                "Models Dart créés",
                "Documentation mise à jour"
            ]
        elif "MISY-006" in card_data["name"]:
            checklist_items = [
                "Structure payment_methods adaptée",
                "Support multi-méthodes implémenté",
                "Migration des données existantes",
                "Tests de non-régression"
            ]
        elif "MISY-007" in card_data["name"]:
            checklist_items = [
                "Service wallet créé",
                "Provider wallet implémenté",
                "Méthodes CRUD fonctionnelles",
                "Tests unitaires complets"
            ]
        else:  # MISY-008
            checklist_items = [
                "Service payment methods étendu",
                "Support multi-méthodes complet",
                "Validations métier en place",
                "Tests unitaires passants"
            ]
            
        checklist = client._make_request('POST', f'/cards/{card["id"]}/checklists', 
                                       data={'name': 'Critères d\'acceptation'})
        for item_name in checklist_items:
            client._make_request('POST', f'/checklists/{checklist["id"]}/checkItems',
                               data={'name': item_name})
        
        created_cards.append(card)
        print(f"✅ {card_data['name']}")
    
    # Créer les cartes Phase 2
    print("\n🎨 Phase 2 - Composants d'interface:")
    for card_data in phase2_cards:
        card = client.create_card(**card_data)
        
        # Checklists Phase 2
        if "MISY-009" in card_data["name"]:
            checklist_items = [
                "Widget affichage solde créé",
                "Bottom sheet recharge fonctionnel",
                "Animations implémentées",
                "Design validé"
            ]
        elif "MISY-010" in card_data["name"]:
            checklist_items = [
                "Nouveau design cartes implémenté",
                "Logos intégrés",
                "Formatage numéros correct",
                "Style moderne appliqué"
            ]
        elif "MISY-011" in card_data["name"]:
            checklist_items = [
                "Bottom sheet créé",
                "Formulaires dynamiques",
                "Validation temps réel",
                "Animations fluides"
            ]
        else:  # MISY-012
            checklist_items = [
                "Bouton moderne créé",
                "Intégration dans la page",
                "Interactions fonctionnelles",
                "Design approuvé"
            ]
            
        checklist = client._make_request('POST', f'/cards/{card["id"]}/checklists',
                                       data={'name': 'Critères d\'acceptation'})
        for item_name in checklist_items:
            client._make_request('POST', f'/checklists/{checklist["id"]}/checkItems',
                               data={'name': item_name})
        
        created_cards.append(card)
        print(f"✅ {card_data['name']}")
    
    # Créer les cartes Phase 3
    print("\n🔄 Phase 3 - Interactions et navigation:")
    for card_data in phase3_cards:
        card = client.create_card(**card_data)
        
        # Checklists Phase 3
        if "MISY-013" in card_data["name"]:
            checklist_items = [
                "Icônes supprimées",
                "Tap direct fonctionnel",
                "Feedback visuel en place",
                "États visuels cohérents"
            ]
        elif "MISY-014" in card_data["name"]:
            checklist_items = [
                "Modal configuration créé",
                "Actions CRUD intégrées",
                "Confirmations en place",
                "UX fluide validée"
            ]
        else:  # MISY-015
            checklist_items = [
                "Provider unifié",
                "Sync Firestore temps réel",
                "Cache local optimisé",
                "Gestion erreurs robuste"
            ]
            
        checklist = client._make_request('POST', f'/cards/{card["id"]}/checklists',
                                       data={'name': 'Critères d\'acceptation'})
        for item_name in checklist_items:
            client._make_request('POST', f'/checklists/{checklist["id"]}/checkItems',
                               data={'name': item_name})
        
        created_cards.append(card)
        print(f"✅ {card_data['name']}")
    
    # Créer les cartes Phase 4
    print("\n✅ Phase 4 - Intégration et validation:")
    for card_data in phase4_cards:
        card = client.create_card(**card_data)
        
        # Checklists Phase 4
        if "MISY-016" in card_data["name"]:
            checklist_items = [
                "Page refactorée",
                "Tous composants intégrés",
                "Navigation fonctionnelle",
                "Performance optimisée"
            ]
        else:  # MISY-017
            checklist_items = [
                "Validations complètes",
                "Sécurité renforcée",
                "Tests unitaires passants",
                "Tests intégration OK",
                "Documentation à jour"
            ]
            
        checklist = client._make_request('POST', f'/cards/{card["id"]}/checklists',
                                       data={'name': 'Critères d\'acceptation'})
        for item_name in checklist_items:
            client._make_request('POST', f'/checklists/{checklist["id"]}/checkItems',
                               data={'name': item_name})
        
        created_cards.append(card)
        print(f"✅ {card_data['name']}")
    
    print(f"\n🎉 Terminé! {len(created_cards)} cartes créées avec succès.")
    print("\n📊 Résumé:")
    print(f"- 1 carte parent (Backlog)")
    print(f"- 4 cartes Phase 1 (À faire)")
    print(f"- 9 cartes Phases 2-4 (Backlog)")
    
    return created_cards

if __name__ == "__main__":
    create_wallet_refactoring_cards()