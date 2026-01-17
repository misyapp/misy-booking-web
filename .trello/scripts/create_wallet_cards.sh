#!/bin/bash

# Script pour créer les cartes Trello de la refactorisation portefeuille

# Charger la configuration
CONFIG_FILE=".trello/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Extraire les credentials
API_KEY=$(jq -r '.api_key' "$CONFIG_FILE")
TOKEN=$(jq -r '.token' "$CONFIG_FILE")
BOARD_ID=$(jq -r '.board_id' "$CONFIG_FILE")

# URL de base
BASE_URL="https://api.trello.com/1"

# Récupérer les IDs des listes
echo "🔄 Récupération des listes..."
LISTS=$(curl -s "${BASE_URL}/boards/${BOARD_ID}/lists?key=${API_KEY}&token=${TOKEN}")
BACKLOG_ID=$(echo "$LISTS" | jq -r '.[] | select(.name == "Backlog") | .id')
TODO_ID=$(echo "$LISTS" | jq -r '.[] | select(.name == "À faire") | .id')

echo "📋 Listes trouvées:"
echo "  - Backlog: $BACKLOG_ID"
echo "  - À faire: $TODO_ID"

# Fonction pour créer une carte
create_card() {
    local name="$1"
    local desc="$2"
    local list_id="$3"
    local labels="$4"
    
    echo "  📝 Création: $name"
    
    # Créer la carte
    RESPONSE=$(curl -s -X POST "${BASE_URL}/cards" \
        -d "key=${API_KEY}" \
        -d "token=${TOKEN}" \
        -d "name=${name}" \
        -d "desc=${desc}" \
        -d "idList=${list_id}" \
        -d "pos=bottom")
    
    CARD_ID=$(echo "$RESPONSE" | jq -r '.id')
    
    if [ "$CARD_ID" != "null" ] && [ -n "$CARD_ID" ]; then
        echo "    ✅ Carte créée: $CARD_ID"
        
        # Ajouter les labels si fournis
        if [ -n "$labels" ]; then
            curl -s -X POST "${BASE_URL}/cards/${CARD_ID}/idLabels" \
                -d "key=${API_KEY}" \
                -d "token=${TOKEN}" \
                -d "value=${labels}" > /dev/null
        fi
        
        echo "$CARD_ID"
    else
        echo "    ❌ Erreur lors de la création"
        echo "$RESPONSE" | jq '.'
        return 1
    fi
}

# Créer ou récupérer le label Urgent
echo "🏷️  Gestion des labels..."
LABELS=$(curl -s "${BASE_URL}/boards/${BOARD_ID}/labels?key=${API_KEY}&token=${TOKEN}")
URGENT_LABEL=$(echo "$LABELS" | jq -r '.[] | select(.name | contains("Urgent")) | .id' | head -1)

if [ -z "$URGENT_LABEL" ] || [ "$URGENT_LABEL" = "null" ]; then
    echo "  📌 Création du label Urgent..."
    URGENT_LABEL=$(curl -s -X POST "${BASE_URL}/boards/${BOARD_ID}/labels" \
        -d "key=${API_KEY}" \
        -d "token=${TOKEN}" \
        -d "name=🔴 Urgent" \
        -d "color=red" | jq -r '.id')
fi

echo ""
echo "🚀 Création des cartes pour la refactorisation du portefeuille..."
echo ""

# Carte parent
echo "📦 Phase 0 - Carte parent:"
PARENT_DESC="## Description
Refonte complète du système de portefeuille pour permettre :
- Un wallet intégré avec solde rechargeable
- Plusieurs méthodes de paiement du même type
- Interface moderne avec cartes de paiement redesignées
- Interactions simplifiées et intuitives

## Structure
- Phase 1: Backend & Structure de données (MISY-005 à MISY-008)
- Phase 2: Composants UI (MISY-009 à MISY-012)
- Phase 3: Interactions (MISY-013 à MISY-015)
- Phase 4: Intégration (MISY-016 à MISY-017)"

create_card "MISY-004: Refactorisation complète du système de portefeuille" "$PARENT_DESC" "$BACKLOG_ID" "$URGENT_LABEL"

echo ""
echo "💾 Phase 1 - Backend & Structure de données:"

# MISY-005
DESC_005="## Description
Concevoir et implémenter la structure de données pour le wallet utilisateur dans Firestore.

## Fichiers concernés
- lib/models/wallet_model.dart (nouveau)
- lib/models/wallet_transaction_model.dart (nouveau)

## Structure proposée
users/{userId}/wallet
- balance: number
- currency: string (MGA)
- created_at: timestamp

users/{userId}/wallet_transactions/{transactionId}
- amount: number
- type: string (credit/debit)
- source: string
- created_at: timestamp"

create_card "MISY-005: Modélisation des données Wallet" "$DESC_005" "$TODO_ID"

# MISY-006
DESC_006="## Description
Adapter la structure de données pour permettre l'ajout de plusieurs méthodes de paiement du même type.

## Fichiers concernés
- lib/models/payment_method_model.dart
- lib/provider/payment_method_provider.dart

## Structure proposée
users/{userId}/payment_methods/{methodId}
- id: string
- type: string (mvola/orange_money/airtel_money/card)
- display_name: string
- account_number: string (masqué)
- is_default: boolean"

create_card "MISY-006: Modélisation méthodes de paiement multiples" "$DESC_006" "$TODO_ID"

# MISY-007
DESC_007="## Description
Développer les services nécessaires pour gérer les opérations du wallet côté client.

## Fichiers concernés
- lib/services/wallet_service.dart (nouveau)
- lib/provider/wallet_provider.dart (nouveau)

## Fonctionnalités
- getWalletBalance()
- rechargeWallet(amount, paymentMethodId)
- debitWallet(amount, tripId)
- getTransactionHistory()"

create_card "MISY-007: Services de gestion du Wallet" "$DESC_007" "$TODO_ID"

# MISY-008
DESC_008="## Description
Développer les services pour la gestion CRUD des méthodes de paiement.

## Fichiers concernés
- lib/services/payment_method_service.dart
- lib/provider/payment_method_provider.dart

## Fonctionnalités
- addPaymentMethod(type, details)
- getPaymentMethods()
- updatePaymentMethod(id, details)
- deletePaymentMethod(id)
- setDefaultPaymentMethod(id)"

create_card "MISY-008: Services CRUD méthodes de paiement" "$DESC_008" "$TODO_ID"

echo ""
echo "🎨 Phase 2 - Composants UI:"

# Les cartes UI restent dans le backlog
# MISY-009
DESC_009="## Description
Créer l'interface utilisateur pour afficher et gérer le wallet.

## Fichiers concernés
- lib/widget/wallet_balance_widget.dart (nouveau)
- lib/widget/wallet_recharge_sheet.dart (nouveau)

## Spécifications UI
- Card avec solde en gros caractères
- Bouton Recharger prominent
- Montants prédéfinis (5000, 10000, 20000 Ar)
- Historique accessible via icône"

create_card "MISY-009: Composant d'affichage du Wallet" "$DESC_009" "$BACKLOG_ID"

# MISY-010
DESC_010="## Description
Moderniser l'affichage des méthodes de paiement selon les spécifications design.

## Fichiers concernés
- lib/widget/payment_method_card.dart

## Spécifications
- Cartes individuelles fond blanc
- Coins arrondis 12-16px
- Logo du service visible
- Numéro masqué format: 03•• ••• 445
- Radio button pour sélection"

create_card "MISY-010: Redesign cartes de méthodes de paiement" "$DESC_010" "$BACKLOG_ID"

# MISY-011
DESC_011="## Description
Créer l'interface modale pour ajouter de nouvelles méthodes de paiement.

## Fichiers concernés
- lib/bottom_sheet_widget/add_payment_method_sheet.dart (nouveau)

## Spécifications
- DraggableScrollableSheet
- Backdrop semi-transparent
- Animation smooth 300ms
- Formulaires dynamiques
- Validation temps réel"

create_card "MISY-011: Bottom Sheet d'ajout de méthode" "$DESC_011" "$BACKLOG_ID"

# MISY-012
DESC_012="## Description
Redesigner le bouton Ajouter un mode de paiement.

## Fichiers concernés
- lib/widget/add_payment_button.dart (nouveau)

## Spécifications
- Bouton large avec icône +
- Hauteur: 48px
- Border radius: 8px
- Ripple effect au tap"

create_card "MISY-012: Bouton d'ajout modernisé" "$DESC_012" "$BACKLOG_ID"

echo ""
echo "🔄 Phase 3 - Interactions:"

# MISY-013
DESC_013="## Description
Implémenter les nouvelles interactions pour les méthodes de paiement.

## Changements
- Supprimer icônes corbeille et modification
- Tap sur carte → ouvre configuration
- Long press → sélection rapide
- Feedback visuel approprié"

create_card "MISY-013: Gestion interactions cartes de paiement" "$DESC_013" "$BACKLOG_ID"

# MISY-014
DESC_014="## Description
Créer l'interface de modification/suppression des méthodes.

## Fonctionnalités
- Affichage détails de la méthode
- Switch Définir par défaut
- Bouton Modifier
- Bouton Supprimer avec confirmation"

create_card "MISY-014: Modal configuration méthodes existantes" "$DESC_014" "$BACKLOG_ID"

# MISY-015
DESC_015="## Description
Implémenter la logique de gestion d'état pour toutes les fonctionnalités.

## Points clés
- État centralisé avec ChangeNotifier
- Sync temps réel Firestore
- Cache local pour performance
- Gestion états loading/error/success"

create_card "MISY-015: Gestion d'état et logique métier" "$DESC_015" "$BACKLOG_ID"

echo ""
echo "✅ Phase 4 - Intégration:"

# MISY-016
DESC_016="## Description
Assembler tous les composants dans la page principale.

## Structure
1. Header avec titre
2. Section Wallet
3. Section Modes de paiement
4. Liste des cartes
5. Bouton d'ajout"

create_card "MISY-016: Intégration page Mon portefeuille" "$DESC_016" "$BACKLOG_ID"

# MISY-017
DESC_017="## Description
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

create_card "MISY-017: Validation, sécurité et tests" "$DESC_017" "$BACKLOG_ID"

echo ""
echo "🎉 Création terminée!"
echo ""
echo "📊 Résumé:"
echo "  - 1 carte parent (Backlog)"
echo "  - 4 cartes Phase 1 (À faire)"
echo "  - 9 cartes Phases 2-4 (Backlog)"
echo ""
echo "💡 Les cartes de la Phase 1 sont prêtes à être travaillées."
echo "   Les autres phases seront déplacées vers 'À faire' au fur et à mesure."