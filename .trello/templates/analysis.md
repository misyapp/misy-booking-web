# 📊 Analyse du Board {{board_name}}

**Date:** {{date}}  
**Dernière synchronisation:** {{last_sync}}

## 📈 Vue d'ensemble

- **Total des tâches:** {{total_tasks}}
- **Backlog:** {{backlog_count}}
- **À faire:** {{todo_count}}
- **En cours:** {{in_progress_count}}
- **Terminées:** {{done_count}}

## 🎯 Tâches Prioritaires

{{#priority_tasks}}
### {{index}}. {{name}} ({{id}})
- **Score de priorité:** {{priority_score}}
- **Raisons:** {{priority_factors}}
- **Complexité estimée:** {{complexity}} (~{{estimated_hours}}h)
- **Dépendances:** {{dependencies}}
{{/priority_tasks}}

## ⚠️ Tâches Nécessitant Clarification

{{#unclear_tasks}}
### {{name}} ({{id}})
- **Score de clarté:** {{clarity_score}}/1.0
- **Problèmes identifiés:**
{{#issues}}
  - {{.}}
{{/issues}}
- **Questions suggérées:**
{{#suggested_questions}}
  - {{.}}
{{/suggested_questions}}
{{/unclear_tasks}}

## 🔗 Suggestions de Regroupement

{{#grouping_suggestions}}
### Groupe {{index}}
**Raison:** {{reason}}
**Économie estimée:** {{time_saved}}

Tâches à regrouper:
{{#tasks}}
- {{name}} ({{id}})
{{/tasks}}
{{/grouping_suggestions}}

## ⏱️ Estimation Globale

- **Temps total estimé:** {{total_hours}} heures
- **Équivalent en jours:** {{total_days}} jours (8h/jour)
- **Charge par développeur:** {{hours_per_dev}} heures ({{dev_count}} développeurs)

## 📊 Répartition par Type

{{#task_types}}
- **{{type}}:** {{count}} tâches ({{percentage}}%)
{{/task_types}}

## 💡 Recommandations

{{#recommendations}}
- {{.}}
{{/recommendations}}

---
*Généré automatiquement par le système Trello-Claude*