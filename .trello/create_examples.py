#!/usr/bin/env python3
"""
Script pour créer des exemples de bonnes et mauvaises pratiques
"""

import requests
import json
import os

# Configuration
config_path = os.path.join(os.path.dirname(__file__), 'config.json')
with open(config_path, 'r') as f:
    config = json.load(f)

api_key = config['api_key']
token = config['token']
board_id = config['board_id']
base_url = 'https://api.trello.com/1'

def get_lists():
    """Récupérer les listes du board"""
    url = f'{base_url}/boards/{board_id}/lists'
    params = {'key': api_key, 'token': token}
    
    response = requests.get(url, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Erreur récupération listes: {response.text}")
        return []

def create_card(name, desc, list_id, pos="bottom"):
    """Créer une carte dans une liste"""
    url = f'{base_url}/cards'
    data = {
        'key': api_key,
        'token': token,
        'name': name,
        'desc': desc,
        'idList': list_id,
        'pos': pos
    }
    
    response = requests.post(url, data=data)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Erreur création carte: {response.text}")
        return None

def add_checklist(card_id, checklist_name, items):
    """Ajouter une checklist à une carte"""
    url = f'{base_url}/checklists'
    data = {
        'key': api_key,
        'token': token,
        'idCard': card_id,
        'name': checklist_name
    }
    
    response = requests.post(url, data=data)
    if response.status_code == 200:
        checklist = response.json()
        checklist_id = checklist['id']
        
        for item in items:
            item_url = f'{base_url}/checklists/{checklist_id}/checkItems'
            item_data = {
                'key': api_key,
                'token': token,
                'name': item
            }
            requests.post(item_url, data=item_data)
        
        return checklist
    else:
        print(f"❌ Erreur création checklist: {response.text}")
        return None

def main():
    print("💡 Création d'exemples de bonnes pratiques...")
    
    # Récupérer les listes
    lists = get_lists()
    backlog_list = None
    
    for lst in lists:
        if lst['name'] == 'Backlog':
            backlog_list = lst
            break
    
    if not backlog_list:
        print("❌ Liste 'Backlog' non trouvée")
        return
    
    # Exemple 1: Bonne pratique - Bug fix
    print("✅ Création d'un exemple de BONNE pratique (Bug)...")
    
    good_bug_title = "✅ EXEMPLE BONNE PRATIQUE - MISY-102: Corriger timeout Orange Money"
    good_bug_desc = """## Description
Corriger le problème de timeout qui se produit lors des paiements Orange Money quand la connexion réseau est lente (> 30 secondes).

## Contexte
Les utilisateurs rapportent des échecs de paiement avec Orange Money, particulièrement dans les zones avec une connexion 3G faible. Cela représente 15% des transactions échouées selon les logs Firebase.

## Fichiers concernés
- `lib/provider/orange_money_payment_gateway_provider.dart`
- `lib/services/payment_retry_service.dart` (à créer)
- `test/provider/orange_money_provider_test.dart`

## Impact estimé
- Réduction de 80% des timeouts Orange Money
- Amélioration de l'expérience utilisateur dans les zones à faible connectivité
- Augmentation du taux de succès des paiements de 85% à 95%

## Reproduction du Bug
1. Activer la limitation réseau (3G lent)
2. Initier un paiement Orange Money
3. Observer le timeout après 30 secondes

## Solution Proposée
- Augmenter le timeout à 60 secondes
- Implémenter un système de retry avec backoff exponentiel
- Ajouter une barre de progression pour informer l'utilisateur"""
    
    good_bug_card = create_card(good_bug_title, good_bug_desc, backlog_list['id'])
    
    if good_bug_card:
        # Ajouter checklist
        criteria = [
            "Reproduire le bug en conditions 3G lent",
            "Implémenter timeout à 60 secondes",
            "Ajouter retry logic avec backoff exponentiel", 
            "Créer barre de progression pour feedback utilisateur",
            "Ajouter tests unitaires pour les timeouts",
            "Tester en conditions réseau réelles",
            "Valider avec 10 transactions test",
            "Mesurer l'amélioration du taux de succès"
        ]
        add_checklist(good_bug_card['id'], "Critères d'acceptation", criteria)
        print(f"   ✅ Exemple bug créé: {good_bug_card['shortUrl']}")
    
    # Exemple 2: Bonne pratique - Feature
    print("✅ Création d'un exemple de BONNE pratique (Feature)...")
    
    good_feature_title = "✅ EXEMPLE BONNE PRATIQUE - MISY-203: Ajouter notifications push pour trajets"
    good_feature_desc = """## Description
Implémenter un système de notifications push pour informer les utilisateurs des événements importants liés à leurs trajets (conducteur assigné, arrivée, etc.).

## Contexte
Actuellement, les utilisateurs doivent rester dans l'app pour suivre leur trajet. Les notifications push amélioreront l'UX en permettant aux utilisateurs de vaquer à leurs occupations tout en restant informés.

## Fichiers concernés
- `lib/services/firebase_push_notifications.dart` (existant, à étendre)
- `lib/provider/trip_provider.dart` (ajouter triggers notifications)
- `lib/modal/notification_modal.dart` (nouveau)
- `android/app/src/main/AndroidManifest.xml` (permissions)

## Impact estimé
- Réduction de 40% du temps passé à attendre dans l'app
- Amélioration satisfaction utilisateur (KPI: rating 4.2 → 4.6)
- Diminution des annulations de dernière minute

## Types de Notifications
1. **Conducteur assigné** - "Votre conducteur Marie arrive dans 5 min"
2. **Conducteur proche** - "Votre conducteur est à 1 min"
3. **Trajet commencé** - "Bon voyage vers votre destination!"
4. **Trajet terminé** - "Merci d'avoir utilisé Misy. Notez votre trajet!"

## Design Pattern
Utiliser le pattern Observer avec TripProvider comme subject"""
    
    good_feature_card = create_card(good_feature_title, good_feature_desc, backlog_list['id'])
    
    if good_feature_card:
        criteria = [
            "Configurer Firebase Cloud Messaging",
            "Implémenter NotificationService avec types définis",
            "Intégrer triggers dans TripProvider", 
            "Créer UI pour gérer préférences notifications",
            "Ajouter tests unitaires pour chaque type notification",
            "Tester sur Android et iOS",
            "Valider avec 20 utilisateurs beta",
            "Mesurer impact sur satisfaction (surveys)"
        ]
        add_checklist(good_feature_card['id'], "Critères d'acceptation", criteria)
        print(f"   ✅ Exemple feature créé: {good_feature_card['shortUrl']}")
    
    # Exemple 3: Mauvaise pratique
    print("❌ Création d'un exemple de MAUVAISE pratique...")
    
    bad_title = "❌ EXEMPLE MAUVAISE PRATIQUE - Fix le bug"
    bad_desc = """Réparer le truc qui marche pas bien dans l'app.

Il y a un problème quelque part qu'il faut corriger."""
    
    bad_card = create_card(bad_title, bad_desc, backlog_list['id'])
    
    if bad_card:
        print(f"   ❌ Exemple mauvaise pratique créé: {bad_card['shortUrl']}")
    
    # Carte d'explication
    print("📚 Création de la carte d'explication des exemples...")
    
    explanation_title = "📚 EXPLICATION - Pourquoi ces exemples ?"
    explanation_desc = """# 🎯 Analyse des Exemples

## ✅ Ce qui Rend les BONNES Pratiques Efficaces

### 1. **Titre Descriptif**
- Convention MISY-XXX respectée
- Description claire du problème/besoin
- Émoji pour identification rapide

### 2. **Description Complète**
- **Quoi**: Action précise à réaliser
- **Pourquoi**: Contexte métier et impact utilisateur  
- **Comment**: Fichiers concernés et approche technique
- **Mesurable**: KPIs et critères de succès définis

### 3. **Critères d'Acceptation Précis**
- Étapes testables et vérifiables
- Critères techniques ET métier
- Tests inclus dans le processus

## ❌ Pourquoi la MAUVAISE Pratique Échoue

### Problèmes Identifiés:
- **Titre vague**: "Fix le bug" ne dit rien
- **Description insuffisante**: Aucun contexte
- **Pas de fichiers**: Comment Claude peut-il aider ?
- **Pas de critères**: Comment savoir si c'est fini ?

### Impact sur Claude:
- 🤖 Claude devra demander 5-10 clarifications
- ⏱️ Temps perdu en allers-retours  
- ❓ Risque de malentendus
- 📉 Qualité du résultat dégradée

## 💡 Règle d'Or

> **"Si Claude (ou un développeur externe) ne peut pas comprendre et réaliser la tâche sans poser de questions, la description est incomplète."**

## 🎯 Objectif

Chaque tâche doit être **SMART**:
- **S**pécifique
- **M**esurable  
- **A**tteignable
- **R**elevant
- **T**emporel

---
*Ces exemples servent de référence pour créer des tâches de qualité.*"""
    
    explanation_card = create_card(explanation_title, explanation_desc, backlog_list['id'])
    
    if explanation_card:
        print(f"   📚 Explication créée: {explanation_card['shortUrl']}")
    
    print("\n🎉 Exemples créés avec succès!")
    print("\n📋 Le board contient maintenant:")
    print("   📖 Guide d'utilisation complet")
    print("   📝 Template à copier")
    print("   ✅ Exemples de bonnes pratiques")
    print("   ❌ Exemple de mauvaise pratique") 
    print("   📚 Explication des différences")
    print("   🏷️ Labels de priorité")
    
    print("\n🚀 Les utilisateurs ont maintenant tous les outils pour créer des tâches de qualité!")

if __name__ == '__main__':
    main()