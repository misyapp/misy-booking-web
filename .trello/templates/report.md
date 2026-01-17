# 🤖 Rapport d'Exécution - {{task_name}}

**ID Tâche:** {{task_id}}  
**Date:** {{date}}  
**Durée:** {{duration}}  
**Status:** {{status}}

## 📝 Résumé

{{summary}}

## 🔧 Modifications Effectuées

{{#changes}}
### {{category}}

{{#items}}
- ✅ {{description}}
{{/items}}
{{/changes}}

## 📂 Fichiers Modifiés

```
{{#files}}
{{path}} | {{additions}} +++{{deletions}} ---
{{/files}}
```

**Total:** {{total_files}} fichiers, {{total_additions}} additions, {{total_deletions}} suppressions

## ✅ Tests

### Tests Ajoutés
- **Nombre:** {{tests_added}}
- **Type:** {{test_types}}
- **Couverture:** {{coverage_before}}% → {{coverage_after}}% ({{coverage_delta}}%)

### Résultats
```
{{test_output}}
```

**Status:** {{test_status}}

## 🔍 Validation

| Vérification | Status | Détails |
|-------------|---------|---------|
| Flutter Analyze | {{analyze_status}} | {{analyze_details}} |
| Flutter Test | {{test_status}} | {{test_details}} |
| Dart Format | {{format_status}} | {{format_details}} |
| Lint Rules | {{lint_status}} | {{lint_details}} |

## ⚠️ Points d'Attention

{{#warnings}}
- ⚠️ {{.}}
{{/warnings}}

## 🚀 Prochaines Étapes Suggérées

{{#next_steps}}
- [ ] {{.}}
{{/next_steps}}

## 💻 Commandes de Vérification

```bash
# Récupérer les changements
git checkout {{branch_name}}
git pull origin {{branch_name}}

# Vérifier le code
flutter analyze
flutter test

# Lancer l'application
flutter run
```

## 📊 Métriques

- **Complexité réduite:** {{complexity_reduction}}%
- **Performance:** {{performance_impact}}
- **Maintenabilité:** {{maintainability_score}}/10
- **Sécurité:** {{security_checks}}

## 📋 Checklist de Validation

- [x] Code implémenté selon les spécifications
- [x] Tests unitaires ajoutés et passants
- [x] Code analysé sans erreurs
- [x] Code formaté selon les standards
- [x] Documentation mise à jour
- [x] Review checklist complétée
- [x] Branch prête pour merge

---

**Généré le:** {{timestamp}}  
**Par:** Claude (Assistant IA)  
**Version:** {{version}}

🤖 Generated with [Claude Code](https://claude.ai/code)