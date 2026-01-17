# 🚀 Guide de Démarrage Rapide - Nouvel Agent Claude

## 🎯 Première Chose à Faire

**À CHAQUE DÉBUT DE SESSION**, tu dois IMPÉRATIVEMENT :

```bash
# 1. Vérifier si synchronisation nécessaire (si fichier absent OU > 2h)
ls -la .trello/data/last_sync.json

# 2. Synchroniser avec Trello
./.trello/trello-task.sh sync

# 3. Analyser les tâches et présenter les priorités
./.trello/trello-task.sh analyze
```

## 📋 Workflow Standard d'une Session

### 1. **Synchronisation Automatique** ⚡
```bash
./.trello/trello-task.sh sync && ./.trello/trello-task.sh analyze
```

### 2. **Présenter les Résultats** 📊
Dire à l'utilisateur :
- Nombre de tâches trouvées
- Tâches prioritaires identifiées
- Suggestions de regroupement (si applicable)
- Tâches nécessitant clarification

### 3. **Travailler sur une Tâche** 🔧
```bash
# Récupérer les détails d'une tâche
./.trello/trello-task.sh get TASK_ID

# Si pas claire, demander clarification
./.trello/trello-task.sh clarify TASK_ID "Votre message"

# Après développement, marquer comme terminée
./.trello/trello-task.sh complete TASK_ID "Résumé des changements"
```

## 🎯 Commandes Essentielles

| Commande | Usage | Quand l'utiliser |
|----------|-------|------------------|
| `sync` | Synchronise avec Trello | **Début de session** (obligatoire) |
| `analyze` | Analyse et priorise | **Après sync** (obligatoire) |
| `list [status]` | Liste les tâches | Pour voir toutes les tâches d'un type |
| `get TASK_ID` | Charge une tâche | **Avant de commencer** une tâche |
| `clarify TASK_ID "msg"` | Demande clarification | Si description **pas assez claire** |
| `complete TASK_ID "summary"` | Marque terminée | **Après avoir fini** une tâche |

## 🤖 Comportements Automatiques du Système

### ✅ Ce que le Système Fait Automatiquement
- **Filtre** les cartes de documentation (guides, templates, exemples)
- **Ignore** les cartes système dans l'analyse
- **Détecte** les tâches peu claires (score < 0.7)
- **Priorise** selon urgence, dépendances, échéances
- **Génère** des rapports détaillés après completion
- **Met à jour** Trello automatiquement

### 📖 Cartes Ignorées Automatiquement
Le système ignore ces patterns :
- `📖 GUIDE` - Documentation
- `📝 TEMPLATE` - Templates
- `📚 EXPLICATION` - Explications
- `✅ EXEMPLE BONNE PRATIQUE` - Exemples positifs
- `❌ EXEMPLE MAUVAISE PRATIQUE` - Exemples négatifs
- `🔧 CONFIGURATION` - Config système

## 📊 Interpréter l'Analyse

### Exemple de Sortie d'Analyse :
```
📈 Vue d'ensemble:
   Total: 3 tâches
   À faire: 2
   En cours: 1
   📖 Documentation: 6 cartes (ignorées)

🎯 Tâches Prioritaires:
1. MISY-105: Optimiser chargement carte (ID: 686c2af4...)
   Score: 8
   Complexité: medium (~2h)
```

### Que Faire Ensuite :
1. **Proposer** la tâche prioritaire à l'utilisateur
2. **Récupérer** ses détails avec `get`
3. **Développer** la solution
4. **Compléter** avec `complete`

## 🚨 Erreurs Courantes et Solutions

### "No tasks found"
```bash
# Vérifier qu'il y a des vraies tâches (pas que de la doc)
./.trello/trello-task.sh list all
```

### "Configuration file not found"
```bash
# Reconfigurer
./.trello/trello-task.sh setup
```

### Analyse bizarre
```bash
# Vérifier les patterns de filtrage dans
cat .trello/lib/task_analyzer.py | grep -A 10 "system_card_patterns"
```

## 💡 Bonnes Pratiques

### ✅ Toujours Faire
- **Sync en début de session** (non négociable)
- **Présenter l'analyse** des priorités
- **Demander clarification** si tâche ambiguë
- **Utiliser `get`** avant de commencer une tâche
- **Utiliser `complete`** après avoir fini

### ❌ Ne Jamais Faire
- Commencer sans synchroniser
- Ignorer les tâches prioritaires sans raison
- Oublier de marquer comme terminée
- Modifier les cartes de documentation

## 🔍 Debug et Vérification

### Vérifier l'État du Système
```bash
# État général
python3 ./.trello/lib/sync_manager.py status

# Dernière synchronisation
cat .trello/data/last_sync.json

# Tâche en cours
cat .trello/data/current_task.md
```

### Tester le Filtrage
```bash
# Voir si une carte serait filtrée
python3 -c "
from .trello.lib.task_analyzer import TaskAnalyzer
analyzer = TaskAnalyzer()
print(analyzer.is_system_card({'name': 'Titre à tester'}))
"
```

## 📚 Documentation Complète

- **Guide principal** : `CLAUDE.md` (section "Gestion des Tâches Trello")
- **README détaillé** : `.trello/README.md`
- **Architecture** : `.trello/README.md` section "Architecture"
- **Patterns de filtrage** : `.trello/lib/task_analyzer.py` ligne 28-36

## 🎯 Checklist de Session

- [ ] Synchroniser avec `sync`
- [ ] Analyser avec `analyze`  
- [ ] Présenter les priorités à l'utilisateur
- [ ] Récupérer la tâche choisie avec `get`
- [ ] Si pas claire, utiliser `clarify`
- [ ] Développer la solution
- [ ] Compléter avec `complete` + résumé
- [ ] Suggérer la prochaine tâche logique

---

**Note** : Ce guide est un aide-mémoire pour nouveaux agents Claude. Pour une compréhension complète, consulter `CLAUDE.md` et `.trello/README.md`.

**Version** : 1.0.0 - Compatible avec tous les agents Claude ayant accès aux outils Bash