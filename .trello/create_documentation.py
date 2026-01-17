#!/usr/bin/env python3
"""
Script pour créer la documentation dans Trello
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

def create_card(name, desc, list_id, pos="top"):
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

def create_label(name, color):
    """Créer un label pour le board"""
    url = f'{base_url}/boards/{board_id}/labels'
    data = {
        'key': api_key,
        'token': token,
        'name': name,
        'color': color
    }
    
    response = requests.post(url, data=data)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"❌ Erreur création label: {response.text}")
        return None

def get_labels():
    """Récupérer les labels existants"""
    url = f'{base_url}/boards/{board_id}/labels'
    params = {'key': api_key, 'token': token}
    
    response = requests.get(url, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        return []

def main():
    print("📖 Création de la documentation Trello...")
    
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
    
    # 1. Créer la carte de documentation principale
    print("📋 Création du guide d'utilisation...")
    
    guide_title = "📖 GUIDE - Comment utiliser ce board Trello"
    guide_desc = """# 🚀 Guide d'Utilisation du Board Misy

## 📊 Workflow des Colonnes

1. **Backlog** 📦 - Toutes les tâches identifiées mais pas encore planifiées
2. **À faire** ✅ - Tâches prêtes à être traitées (description complète + critères clairs)
3. **En cours** 🚧 - Tâches actuellement en développement  
4. **À valider** 🔍 - Tâches terminées en attente de validation/review
5. **Terminé** ✔️ - Tâches validées et déployées

## ✍️ Comment Rédiger une Bonne Tâche

### Format du Titre
- **Convention**: `MISY-XXX: Description courte et claire`
- **Exemples**: 
  - `MISY-001: Corriger le bug de timeout Orange Money`
  - `MISY-042: Ajouter notification SMS de confirmation`

### Description Obligatoire
```markdown
## Description
[Que doit-on faire exactement ?]

## Contexte  
[Pourquoi cette tâche est nécessaire ?]

## Fichiers concernés
- `lib/path/to/file.dart`
- `lib/other/file.dart`

## Impact estimé
[Bénéfices attendus]
```

### Critères d'Acceptation
- ✅ Utilisez TOUJOURS les checklists
- ✅ Soyez spécifique et mesurable
- ✅ Incluez les tests nécessaires

## 🤖 Interaction avec Claude

### Claude va automatiquement :
- 🔄 Synchroniser le board chaque session
- 📊 Analyser et prioriser les tâches
- 🤔 Demander des clarifications si nécessaire
- 💡 Suggérer des regroupements de tâches
- 📝 Générer des rapports détaillés

### Quand Claude Demande des Clarifications
- ⚠️ Un label "needs-clarification" sera ajouté
- 💬 Répondez dans les commentaires
- ✅ Mettez à jour la description si nécessaire

## 🏷️ Labels et Priorités

- 🔴 **Urgent** - À traiter immédiatement (bug critique, blocage)
- 🟠 **Important** - Haute priorité (nouvelle fonctionnalité majeure)  
- 🟡 **Normal** - Priorité standard
- ⚪ **À clarifier** - Description incomplète (ajouté par Claude)

## ✅ Checklist Avant Création

Avant de créer une tâche, vérifiez :
- [ ] Titre clair avec convention MISY-XXX
- [ ] Description détaillée avec contexte
- [ ] Critères d'acceptation définis
- [ ] Fichiers concernés identifiés
- [ ] Label de priorité assigné

## 💡 Bonnes Pratiques

### ✅ À Faire
- Décrire le "pourquoi" pas seulement le "quoi"
- Ajouter des exemples concrets
- Mentionner les impacts sur d'autres modules
- Utiliser des termes techniques précis

### ❌ À Éviter  
- Descriptions vagues ("améliorer", "optimiser", "fix bug")
- Tâches trop grandes (> 8h de travail)
- Critères non mesurables
- Oublier le contexte métier

## 📞 Support

- 🤖 Claude analysera automatiquement vos tâches
- 💬 Posez vos questions dans les commentaires
- 📝 Consultez les rapports générés pour apprendre

---
*Créé le {date} - Système Trello-Claude pour Misy* 🚗"""
    
    # Remplacer {date} par la date actuelle
    from datetime import datetime
    guide_desc = guide_desc.replace('{date}', datetime.now().strftime('%d/%m/%Y'))
    
    guide_card = create_card(guide_title, guide_desc, backlog_list['id'], "top")
    
    if guide_card:
        print(f"✅ Guide créé: {guide_card['shortUrl']}")
    
    # 2. Créer le template de tâche
    print("📝 Création du template de tâche...")
    
    template_title = "📝 TEMPLATE - Nouvelle tâche (copiez-moi !)"
    template_desc = """## Description
[Décrivez clairement ce qui doit être fait]

## Contexte
[Expliquez pourquoi cette tâche est nécessaire]

## Fichiers concernés
- `lib/path/to/file.dart`
- `test/path/to/test.dart`

## Impact estimé
- [Bénéfice utilisateur]
- [Impact technique]
- [Métriques attendues]

---
**Instructions :**
1. Copiez cette carte
2. Modifiez le titre avec MISY-XXX
3. Remplissez toutes les sections
4. Ajoutez une checklist avec les critères d'acceptation
5. Assignez un label de priorité"""
    
    template_card = create_card(template_title, template_desc, backlog_list['id'], "2")
    
    if template_card:
        print(f"✅ Template créé: {template_card['shortUrl']}")
    
    # 3. Créer les labels de priorité
    print("🏷️ Création des labels de priorité...")
    
    # Vérifier les labels existants
    existing_labels = get_labels()
    existing_names = [label['name'].lower() for label in existing_labels]
    
    labels_to_create = [
        ('🔴 Urgent', 'red'),
        ('🟠 Important', 'orange'), 
        ('🟡 Normal', 'yellow'),
        ('⚪ À clarifier', 'sky'),
        ('🔗 Groupé', 'green'),
        ('🐛 Bug', 'red'),
        ('✨ Feature', 'blue'),
        ('🔧 Refactor', 'purple')
    ]
    
    for label_name, color in labels_to_create:
        if label_name.lower() not in existing_names:
            label = create_label(label_name, color)
            if label:
                print(f"   ✅ Label '{label_name}' créé")
        else:
            print(f"   ⏭️  Label '{label_name}' existe déjà")
    
    print("\n🎉 Documentation créée avec succès!")
    print("\n📋 Le board est maintenant prêt pour les utilisateurs!")
    print("\n🔗 Liens utiles:")
    if guide_card:
        print(f"   📖 Guide: {guide_card['shortUrl']}")
    if template_card:
        print(f"   📝 Template: {template_card['shortUrl']}")

if __name__ == '__main__':
    main()