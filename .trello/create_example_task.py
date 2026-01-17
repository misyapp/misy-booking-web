#!/usr/bin/env python3
"""
Script pour créer une tâche d'exemple dans Trello
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
    # Créer la checklist
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
        
        # Ajouter les items
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
    print("🚀 Création d'une tâche d'exemple...")
    
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
    
    # Créer la tâche d'exemple
    task_name = "MISY-001: Améliorer l'interface de réservation"
    task_desc = """## Description
Optimiser l'interface utilisateur du processus de réservation pour améliorer l'expérience utilisateur.

## Contexte
Les utilisateurs rapportent que le processus de réservation est trop long et confus.

## Fichiers concernés
- `lib/pages/view_module/home_screen.dart`
- `lib/bottom_sheet_widget/pickup_and_drop_location_sheet.dart`
- `lib/provider/trip_provider.dart`

## Impact estimé
- Réduction du temps de réservation de 30%
- Amélioration de la satisfaction utilisateur
- Diminution du taux d'abandon
"""
    
    print(f"📝 Création de la tâche: {task_name}")
    card = create_card(task_name, task_desc, todo_list['id'])
    
    if card:
        print(f"✅ Tâche créée avec succès! ID: {card['id']}")
        
        # Ajouter une checklist
        checklist_items = [
            "Analyser les points de friction actuels",
            "Créer des wireframes pour la nouvelle interface",
            "Implémenter les changements UI",
            "Ajouter des tests d'interface",
            "Tester avec des utilisateurs pilotes",
            "Déployer en production"
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