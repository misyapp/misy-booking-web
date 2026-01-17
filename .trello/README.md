# Système de Gestion Trello pour Misy

## 🎯 Vue d'Ensemble

Système intelligent de synchronisation bidirectionnelle entre Trello et Claude, permettant :
- ✅ Synchronisation automatique des tâches
- 🤖 Analyse intelligente des priorités par Claude
- 📊 Filtrage automatique des cartes de documentation
- 💡 Suggestions de regroupement et optimisation
- 📝 Génération automatique de rapports détaillés
- 🔄 Workflow complet de gestion des tâches

## 🚀 Installation Rapide

### Première Installation
1. **Assurez-vous d'être dans le projet** :
   ```bash
   cd /home/mathieu/git/riderapp
   ```

2. **Configurez Trello** :
   ```bash
   ./.trello/trello-task.sh setup
   ```
   Vous aurez besoin de :
   - API Key Trello : https://trello.com/app-key
   - Token avec permissions d'écriture
   - Nom ou ID du board

3. **Test de fonctionnement** :
   ```bash
   ./.trello/trello-task.sh sync
   ./.trello/trello-task.sh analyze
   ```

4. **C'est prêt !** 🎉

## 📋 Configuration

### Obtenir vos identifiants Trello

1. Allez sur https://trello.com/app-key
2. Copiez votre **API Key**
3. Cliquez sur "Token" pour générer un token d'accès
4. Identifiez votre board ID ou utilisez simplement le nom du board

### Configuration manuelle (optionnel)

Si vous préférez configurer manuellement :
```bash
cp .trello/config.json.example .trello/config.json
# Éditez .trello/config.json avec vos identifiants
```

## 🎯 Utilisation Quotidienne

### Commandes Principales

```bash
# Synchroniser avec Trello (récupère toutes les tâches)
./.trello/trello-task.sh sync

# Analyser et voir les priorités
./.trello/trello-task.sh analyze

# Lister les tâches
./.trello/trello-task.sh list              # Toutes les tâches
./.trello/trello-task.sh list todo         # Seulement "À faire"
./.trello/trello-task.sh list in_progress  # En cours

# Travailler sur une tâche
./.trello/trello-task.sh get MISY-101      # Charge la tâche

# Demander clarification
./.trello/trello-task.sh clarify MISY-101 "Quelles sont les métriques de performance attendues ?"

# Marquer comme terminée
./.trello/trello-task.sh complete MISY-101 "Ajout du retry logic avec backoff exponentiel"
```

### Workflow Typique

1. **Début de journée** :
   ```bash
   ./.trello/trello-task.sh sync
   ./.trello/trello-task.sh analyze
   ```

2. **Choisir une tâche** :
   ```bash
   ./.trello/trello-task.sh get MISY-087
   ```

3. **Travailler avec Claude** sur la tâche

4. **Terminer la tâche** :
   ```bash
   ./.trello/trello-task.sh complete MISY-087 "Timeout corrigé avec retry logic"
   ```

## 🤖 Intégration avec Claude

### Comportement Automatique de Claude
Claude est configuré pour **automatiquement** :
- 🔄 **Synchroniser** au début de chaque session (si > 2h)
- 📊 **Analyser** et prioriser toutes les vraies tâches  
- 💡 **Suggérer** des regroupements de tâches similaires
- 🤔 **Détecter** les tâches peu claires et demander clarifications
- ⏱️ **Estimer** la complexité et le temps nécessaire
- 📝 **Générer** des rapports détaillés après chaque tâche
- 🎯 **Proposer** les prochaines tâches logiques

### Filtrage Intelligent
Le système **ignore automatiquement** :
- 📖 Cartes de documentation (GUIDE, TEMPLATE, etc.)
- 📚 Cartes d'exemples (bonnes/mauvaises pratiques)
- 🔧 Cartes de configuration système
- Toute carte avec > 500 caractères de documentation

**Résultat** : Claude se concentre uniquement sur les vraies tâches de développement.

## 📊 Fonctionnalités Avancées

### Analyse Intelligente

Le système analyse automatiquement :
- **Clarté des tâches** : Score de 0 à 1 basé sur la description
- **Dépendances** : Identifie les tâches bloquantes
- **Complexité** : Estime le temps nécessaire
- **Priorités** : Ordonne selon urgence et impact

### Suggestions de Regroupement

```bash
./.trello/trello-task.sh group MISY-102 MISY-104
```

Suggère de regrouper des tâches qui :
- Touchent les mêmes fichiers
- Concernent la même fonctionnalité
- Peuvent partager du code ou des tests

## 📁 Structure des Fichiers

```
.trello/
├── config.json              # Vos identifiants (ne pas committer)
├── trello-task.sh          # Script principal
├── lib/                    # Modules Python
│   ├── trello_client.py    # Client API Trello
│   ├── task_analyzer.py    # Analyse des tâches
│   ├── sync_manager.py     # Gestion de la synchronisation
│   └── report_generator.py # Génération des rapports
├── data/                   # Données locales
│   ├── board_state.json    # État actuel du board
│   ├── current_task.md     # Tâche en cours
│   └── last_sync.json      # Timestamp dernière sync
├── templates/              # Templates de messages
└── reports/               # Historique des rapports
```

## 🔧 Dépannage

### Erreur "Configuration file not found"
→ Lancez `./.trello/trello-task.sh setup`

### Erreur "Board not found"
→ Vérifiez le nom/ID du board dans `config.json`

### Erreur d'authentification
→ Vérifiez vos API key et token sur https://trello.com/app-key

## 🔒 Sécurité

- ⚠️ Ne commitez **jamais** `config.json` (contient vos identifiants)
- Le fichier est automatiquement en permissions 600 (lecture seule pour vous)
- Ajoutez `.trello/config.json` à votre `.gitignore`

## 🚀 Tips & Tricks

1. **Alias bash** pour aller plus vite :
   ```bash
   alias tt="./.trello/trello-task.sh"
   alias tts="tt sync"
   alias tta="tt analyze"
   ```

2. **Voir la tâche en cours** :
   ```bash
   cat .trello/data/current_task.md
   ```

3. **Historique des rapports** :
   ```bash
   ls -la .trello/reports/
   ```

## 📞 Support

En cas de problème :
1. Vérifiez les logs dans les scripts Python
2. Consultez la documentation Trello API
3. Demandez à Claude qui connaît bien le système !

---

## 🏗️ Architecture du Système

### Composants Principaux

#### 1. `trello-task.sh` - Script Principal
- Interface unifiée pour toutes les opérations
- Gestion des erreurs et validation
- Coordination entre les modules Python

#### 2. `trello_client.py` - Client API
- Communication directe avec l'API Trello REST
- Gestion de l'authentification
- Opérations CRUD sur les cartes

#### 3. `task_analyzer.py` - Intelligence
- **Filtrage automatique** des cartes système
- **Analyse de clarté** (score 0-1)
- **Détection de dépendances** entre tâches
- **Priorisation intelligente** basée sur multiple critères
- **Suggestions de regroupement** par module/fonctionnalité

#### 4. `sync_manager.py` - Synchronisation
- Synchronisation bidirectionnelle
- Cache local pour performance
- Gestion des conflits

#### 5. `report_generator.py` - Rapports
- Templates de rapports automatiques
- Intégration git et métriques
- Format Markdown professionnel

### Patterns de Détection des Cartes Système

```python
# Dans task_analyzer.py et sync_manager.py
system_card_patterns = [
    r'^📖.*GUIDE',           # Guides d'utilisation
    r'^📝.*TEMPLATE',        # Templates à copier
    r'^📚.*EXPLICATION',     # Explications détaillées
    r'^✅.*EXEMPLE.*BONNE',  # Exemples positifs
    r'^❌.*EXEMPLE.*MAUVAISE', # Exemples négatifs
    r'^🔧.*CONFIGURATION',   # Configuration système
    r'^📋.*DOCUMENTATION'    # Documentation générale
]

# + Détection par contenu : > 500 chars avec mots-clés doc
```

### Flux de Données

```
1. Utilisateur crée tâche dans Trello
   ↓
2. Claude sync automatiquement
   ↓ 
3. task_analyzer filtre et analyse
   ↓
4. Claude présente priorités
   ↓
5. Développement de la solution
   ↓
6. report_generator crée rapport
   ↓
7. Mise à jour automatique Trello
```

### Sécurité et Performance

#### Sécurité
- ✅ Identifiants dans `config.json` (gitignored)
- ✅ Permissions 600 sur le fichier config
- ✅ Validation des entrées API
- ✅ Pas de credentials en dur dans le code

#### Performance  
- ✅ Cache local dans `data/board_state.json`
- ✅ Sync incrémentielle (detection > 2h)
- ✅ Filtrage côté client
- ✅ Batch des opérations API

## 📚 Pour les Développeurs

### Ajouter un Nouveau Pattern de Détection

```python
# Dans task_analyzer.py ligne ~28
system_card_patterns = [
    # ... patterns existants
    r'^🆕.*NOUVEAU_TYPE',  # Votre nouveau pattern
]
```

### Modifier la Logique de Priorisation

```python
# Dans task_analyzer.py, méthode prioritize_tasks()
# Ajouter vos critères personnalisés
if 'votre_critere' in desc:
    priority_score += 5
    factors.append('Votre critère détecté')
```

### Étendre les Rapports

```python
# Dans report_generator.py
# Ajouter vos sections de rapport
```

### Debug et Logs

```bash
# Voir l'état détaillé
python3 ./.trello/lib/sync_manager.py status

# Debug d'une analyse
python3 ./.trello/lib/task_analyzer.py analyze

# Tester un pattern de filtrage
python3 -c "
from lib.task_analyzer import TaskAnalyzer
analyzer = TaskAnalyzer()
print(analyzer.is_system_card({'name': 'Votre titre test'}))
"
```

## 🔮 Évolutions Futures

### Fonctionnalités Prévues
- 📈 Métriques de performance d'équipe
- 🔄 Synchronisation temps réel via webhooks
- 🎯 IA pour estimation automatique des efforts
- 📊 Dashboard de suivi projet
- 🤝 Intégration CI/CD pour auto-completion

### Extensibilité
Le système est conçu pour être facilement étendu :
- Nouveaux providers (GitHub Issues, Jira, etc.)
- Nouveaux types d'analyse
- Nouveaux formats de rapport
- Nouvelles intégrations (Slack, Discord, etc.)

---

Développé pour le projet Misy 🚗 avec ❤️

## 📞 Support Technique

- 📖 **Documentation complète** : `CLAUDE.md`
- 🔧 **Guide de dépannage** : Section "Dépannage Rapide" 
- 🤖 **Support Claude** : Le système est auto-documenté
- 📝 **Issues** : Créer une tâche dans Trello pour les bugs

**Version** : 1.0.0  
**Compatible** : Python 3.7+, Trello API v1  
**Licence** : Projet interne Misy