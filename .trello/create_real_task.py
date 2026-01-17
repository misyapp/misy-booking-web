#!/usr/bin/env python3
"""
Script pour créer une vraie tâche de test
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

def create_card(name, desc, list_id):
    """Créer une carte dans une liste"""
    url = f'{base_url}/cards'
    data = {
        'key': api_key,
        'token': token,
        'name': name,
        'desc': desc,
        'idList': list_id
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
    print("🚀 Création d'une vraie tâche de test...")
    
    # Récupérer les listes
    lists = get_lists()
    
    # Trouver la liste "À faire"
    todo_list = None
    for lst in lists:
        if lst['name'] == 'À faire':
            todo_list = lst
            break
    
    if not todo_list:
        print("❌ Liste 'À faire' non trouvée")
        return
    
    # Créer une vraie tâche
    task_name = "MISY-105: Optimiser le chargement des cartes Google Maps"
    task_desc = """## Description
Réduire le temps de chargement initial des cartes Google Maps de 3-4 secondes à moins de 1.5 seconde.

## Contexte
Les utilisateurs se plaignent que l'app prend trop de temps à afficher la carte lors de l'ouverture. Cela impacte l'expérience utilisateur et peut causer des abandons.

## Fichiers concernés
- `lib/pages/view_module/home_screen.dart`
- `lib/provider/google_map_provider.dart`
- `lib/services/location.dart`

## Impact estimé
- Amélioration du temps de chargement de 60%
- Réduction du taux d'abandon de l'écran d'accueil
- Meilleure satisfaction utilisateur
"""
    
    print(f"📝 Création de la tâche: {task_name}")
    card = create_card(task_name, task_desc, todo_list['id'])
    
    if card:
        print(f"✅ Tâche créée avec succès! ID: {card['id']}")
        
        # Ajouter une checklist
        checklist_items = [
            "Profiler les performances actuelles de chargement",
            "Identifier les goulots d'étranglement",
            "Implémenter le lazy loading pour la carte",
            "Optimiser les requêtes de géolocalisation",
            "Ajouter un cache pour les données de carte",
            "Tester les performances après optimisation",
            "Valider sur différents appareils (Android/iOS)"
        ]
        
        print("📋 Ajout des critères d'acceptation...")
        checklist = add_checklist(card['id'], "Critères d'acceptation", checklist_items)
        
        if checklist:
            print("✅ Checklist ajoutée avec succès!")
        
        print(f"\n🔗 Lien vers la tâche: {card['shortUrl']}")
        print(f"📊 ID de la tâche: {card['id']}")
        
    else:
        print("❌ Échec de création de la tâche")

if __name__ == '__main__':
    main()