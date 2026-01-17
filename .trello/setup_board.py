#!/usr/bin/env python3
"""
Script pour initialiser les colonnes du board Trello
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

def create_list(name, pos="bottom"):
    """Créer une liste sur le board"""
    url = f'{base_url}/lists'
    data = {
        'key': api_key,
        'token': token,
        'name': name,
        'idBoard': board_id,
        'pos': pos
    }
    
    response = requests.post(url, data=data)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Erreur création liste '{name}': {response.text}")
        return None

def get_existing_lists():
    """Récupérer les listes existantes"""
    url = f'{base_url}/boards/{board_id}/lists'
    params = {'key': api_key, 'token': token}
    
    response = requests.get(url, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Erreur récupération listes: {response.text}")
        return []

def main():
    print("🚀 Initialisation du board Trello...")
    
    # Vérifier les listes existantes
    existing_lists = get_existing_lists()
    existing_names = [lst['name'] for lst in existing_lists]
    
    print(f"📋 Listes existantes: {existing_names}")
    
    # Listes à créer
    lists_to_create = [
        "Backlog",
        "À faire", 
        "En cours",
        "À valider",
        "Terminé"
    ]
    
    created_count = 0
    for list_name in lists_to_create:
        if list_name not in existing_names:
            print(f"➕ Création de la liste '{list_name}'...")
            result = create_list(list_name)
            if result:
                print(f"✅ Liste '{list_name}' créée avec succès")
                created_count += 1
            else:
                print(f"❌ Échec création de '{list_name}'")
        else:
            print(f"⏭️  Liste '{list_name}' existe déjà")
    
    print(f"\n🎉 Configuration terminée! {created_count} nouvelles listes créées.")
    print("\n📋 Board prêt pour la synchronisation!")

if __name__ == '__main__':
    main()