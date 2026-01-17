#!/bin/bash

# Script pour compléter la création des cartes manquantes

# Charger la configuration
CONFIG_FILE=".trello/config.json"
API_KEY=$(jq -r '.api_key' "$CONFIG_FILE")
TOKEN=$(jq -r '.token' "$CONFIG_FILE")
BOARD_ID=$(jq -r '.board_id' "$CONFIG_FILE")
BASE_URL="https://api.trello.com/1"

# IDs des listes
BACKLOG_ID="686c27ca1d2d8914b466bfdb"

# Fonction pour créer une carte simple
create_simple_card() {
    local name="$1"
    local desc="$2"
    
    echo "📝 Création: $name"
    
    curl -s -X POST "${BASE_URL}/cards" \
        -d "key=${API_KEY}" \
        -d "token=${TOKEN}" \
        -d "name=${name}" \
        -d "desc=${desc}" \
        -d "idList=${BACKLOG_ID}" > /dev/null
    
    echo "✅ Créé"
}

echo "🚀 Complétion des cartes manquantes..."
echo ""

# Phase 2 cartes manquantes
echo "🎨 Phase 2 - Cartes manquantes:"

create_simple_card "MISY-010: Redesign cartes de méthodes de paiement" "## Description
Moderniser l'affichage des méthodes de paiement selon les spécifications design.

## Fichiers concernés
- lib/widget/payment_method_card.dart

## Spécifications
- Cartes individuelles fond blanc
- Coins arrondis 12-16px
- Logo du service visible
- Numéro masqué format: 03•• ••• 445
- Radio button pour sélection"

create_simple_card "MISY-011: Bottom Sheet d'ajout de méthode" "## Description
Créer l'interface modale pour ajouter de nouvelles méthodes de paiement.

## Fichiers concernés
- lib/bottom_sheet_widget/add_payment_method_sheet.dart (nouveau)

## Spécifications
- DraggableScrollableSheet
- Backdrop semi-transparent
- Animation smooth 300ms
- Formulaires dynamiques
- Validation temps réel"

create_simple_card "MISY-012: Bouton d'ajout modernisé" "## Description
Redesigner le bouton Ajouter un mode de paiement.

## Fichiers concernés
- lib/widget/add_payment_button.dart (nouveau)

## Spécifications
- Bouton large avec icône +
- Hauteur: 48px
- Border radius: 8px
- Ripple effect au tap"

echo ""
echo "🔄 Phase 3 - Interactions:"

create_simple_card "MISY-013: Gestion interactions cartes de paiement" "## Description
Implémenter les nouvelles interactions pour les méthodes de paiement.

## Changements
- Supprimer icônes corbeille et modification
- Tap sur carte → ouvre configuration
- Long press → sélection rapide
- Feedback visuel approprié"

create_simple_card "MISY-014: Modal configuration méthodes existantes" "## Description
Créer l'interface de modification/suppression des méthodes.

## Fonctionnalités
- Affichage détails de la méthode
- Switch Définir par défaut
- Bouton Modifier
- Bouton Supprimer avec confirmation"

create_simple_card "MISY-015: Gestion d'état et logique métier" "## Description
Implémenter la logique de gestion d'état pour toutes les fonctionnalités.

## Points clés
- État centralisé avec ChangeNotifier
- Sync temps réel Firestore
- Cache local pour performance
- Gestion états loading/error/success"

echo ""
echo "✅ Phase 4 - Intégration:"

create_simple_card "MISY-016: Intégration page Mon portefeuille" "## Description
Assembler tous les composants dans la page principale.

## Structure
1. Header avec titre
2. Section Wallet
3. Section Modes de paiement
4. Liste des cartes
5. Bouton d'ajout"

create_simple_card "MISY-017: Validation, sécurité et tests" "## Description
Implémenter validations et sécurité.

## Points de validation
- Format numéros téléphone
- Format cartes bancaires
- Montants min/max
- Données sensibles sécurisées

## Tests
- Tests unitaires
- Tests widgets
- Tests intégration
- Tests performance"

echo ""
echo "🎉 Toutes les cartes ont été créées!"