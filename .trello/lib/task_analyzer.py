#!/usr/bin/env python3
"""
Task Analyzer for Misy Project
Analyzes Trello tasks to provide insights, prioritization, and suggestions
"""

import json
import os
import sys
import re
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional, Any
from collections import defaultdict

class TaskAnalyzer:
    """Analyzer for Trello tasks with intelligent suggestions"""
    
    def __init__(self, data_dir: str = None):
        """Initialize task analyzer"""
        if data_dir is None:
            data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
        
        self.data_dir = data_dir
        self.board_state_file = os.path.join(data_dir, 'board_state.json')
        self.history_file = os.path.join(data_dir, 'task_history.json')
        
        # Patterns pour identifier les cartes système/documentation
        self.system_card_patterns = [
            r'^📖.*GUIDE',
            r'^📝.*TEMPLATE',
            r'^📚.*EXPLICATION',
            r'^✅.*EXEMPLE.*BONNE.*PRATIQUE',
            r'^❌.*EXEMPLE.*MAUVAISE.*PRATIQUE',
            r'^🔧.*CONFIGURATION',
            r'^📋.*DOCUMENTATION'
        ]
        
        # Load board state
        if os.path.exists(self.board_state_file):
            with open(self.board_state_file, 'r') as f:
                self.board_state = json.load(f)
        else:
            self.board_state = {'tasks': []}
        
        # Load history for estimations
        if os.path.exists(self.history_file):
            with open(self.history_file, 'r') as f:
                self.history = json.load(f)
        else:
            self.history = {'completed_tasks': []}
    
    def is_system_card(self, task: Dict) -> bool:
        """
        Determine if a task is a system/documentation card
        """
        task_name = task.get('name', '')
        
        # Check against patterns
        for pattern in self.system_card_patterns:
            if re.match(pattern, task_name, re.IGNORECASE):
                return True
        
        # Check for documentation keywords in description
        desc = task.get('desc', '').lower()
        doc_keywords = ['exemple', 'template', 'guide', 'documentation', 'explication']
        
        if any(keyword in desc for keyword in doc_keywords) and len(desc) > 500:
            return True
        
        return False
    
    def filter_real_tasks(self, tasks: List[Dict]) -> List[Dict]:
        """
        Filter out system/documentation cards to keep only real work tasks
        """
        return [task for task in tasks if not self.is_system_card(task)]
    
    def analyze_clarity(self, task: Dict) -> Tuple[float, List[str]]:
        """
        Analyze task clarity and return score (0-1) with issues
        """
        score = 1.0
        issues = []
        
        # Check description length
        desc = task.get('desc', '')
        if len(desc) < 50:
            score -= 0.3
            issues.append("Description trop courte (< 50 caractères)")
        
        # Check for acceptance criteria
        has_checklist = bool(task.get('checklists'))
        if not has_checklist:
            score -= 0.2
            issues.append("Pas de critères d'acceptation définis")
        
        # Check for technical details
        technical_keywords = ['fichier', 'module', 'fonction', 'api', 'endpoint', 'base de données']
        has_technical = any(keyword in desc.lower() for keyword in technical_keywords)
        
        if not has_technical and len(desc) > 50:
            score -= 0.1
            issues.append("Manque de détails techniques")
        
        # Check for examples or specifics
        example_indicators = ['exemple', 'ex:', 'e.g.', 'par exemple', 'comme']
        has_examples = any(indicator in desc.lower() for indicator in example_indicators)
        
        if not has_examples and score < 0.8:
            score -= 0.1
            issues.append("Pas d'exemples fournis")
        
        # Check for ambiguous language
        ambiguous_terms = ['améliorer', 'optimiser', 'fix', 'réparer', 'bug', 'problème', 'certains', 'quelques']
        ambiguous_count = sum(1 for term in ambiguous_terms if term in desc.lower())
        
        if ambiguous_count > 2:
            score -= 0.2
            issues.append("Langage trop vague ou ambigu")
        
        return max(0, score), issues
    
    def find_dependencies(self, task: Dict, all_tasks: List[Dict]) -> List[str]:
        """
        Find potential dependencies based on task content
        """
        dependencies = []
        task_desc = task.get('desc', '').lower()
        task_name = task.get('name', '').lower()
        
        for other_task in all_tasks:
            if other_task['id'] == task['id']:
                continue
            
            other_desc = other_task.get('desc', '').lower()
            other_name = other_task.get('name', '').lower()
            
            # Check for explicit mentions
            if other_task['id'] in task_desc or other_task['id'] in task_name:
                dependencies.append(other_task['id'])
                continue
            
            # Check for module/feature overlap
            # Extract potential module names (e.g., "payment", "auth", "map")
            modules = re.findall(r'\b(payment|paiement|auth|authentification|map|carte|booking|réservation)\b', 
                               task_desc + ' ' + task_name)
            
            for module in modules:
                if module in other_desc or module in other_name:
                    # Check if the other task is not completed
                    if other_task.get('list') != 'done':
                        dependencies.append(other_task['id'])
                        break
        
        return list(set(dependencies))
    
    def suggest_grouping(self, all_tasks: List[Dict]) -> List[List[str]]:
        """
        Suggest tasks that could be grouped together
        """
        # Filter out system cards
        real_tasks = self.filter_real_tasks(all_tasks)
        
        groups = []
        processed = set()
        
        # Group by similar files/modules
        file_groups = defaultdict(list)
        
        for task in real_tasks:
            if task.get('list') in ['done', 'in_progress']:
                continue
            
            # Extract file references
            desc = task.get('desc', '') + ' ' + task.get('name', '')
            files = re.findall(r'(\w+\.dart|\w+\.py|\w+\.js)', desc)
            
            for file in files:
                file_groups[file].append(task['id'])
        
        # Add groups with more than one task
        for file, task_ids in file_groups.items():
            if len(task_ids) > 1:
                groups.append(task_ids)
                processed.update(task_ids)
        
        # Group by similar functionality
        functionality_keywords = {
            'payment': ['payment', 'paiement', 'orange money', 'airtel', 'mvola'],
            'auth': ['auth', 'login', 'signup', 'connexion', 'inscription'],
            'map': ['map', 'carte', 'location', 'position', 'gps'],
            'booking': ['booking', 'réservation', 'trajet', 'ride'],
            'ui': ['ui', 'interface', 'design', 'button', 'screen', 'écran']
        }
        
        for func_name, keywords in functionality_keywords.items():
            func_group = []
            
            for task in real_tasks:
                if task['id'] in processed or task.get('list') in ['done', 'in_progress']:
                    continue
                
                desc = (task.get('desc', '') + ' ' + task.get('name', '')).lower()
                
                if any(keyword in desc for keyword in keywords):
                    func_group.append(task['id'])
            
            if len(func_group) > 1:
                groups.append(func_group)
                processed.update(func_group)
        
        return groups
    
    def estimate_complexity(self, task: Dict) -> Dict[str, Any]:
        """
        Estimate task complexity and time needed
        """
        estimation = {
            'complexity': 'medium',
            'estimated_hours': 2,
            'confidence': 0.5,
            'factors': []
        }
        
        desc = task.get('desc', '').lower()
        name = task.get('name', '').lower()
        full_text = f"{name} {desc}"
        
        # Check for complexity indicators
        complexity_score = 0
        
        # Simple tasks
        if any(word in full_text for word in ['typo', 'rename', 'couleur', 'texte', 'label']):
            complexity_score -= 2
            estimation['factors'].append('Tâche simple identifiée')
        
        # Medium complexity indicators
        if any(word in full_text for word in ['ajouter', 'modifier', 'update', 'fix']):
            complexity_score += 1
            estimation['factors'].append('Modification de code existant')
        
        # High complexity indicators
        if any(word in full_text for word in ['refactor', 'migrate', 'architecture', 'performance']):
            complexity_score += 3
            estimation['factors'].append('Changement architectural')
        
        if any(word in full_text for word in ['api', 'integration', 'firebase', 'payment']):
            complexity_score += 2
            estimation['factors'].append('Intégration externe')
        
        # Check number of files potentially affected
        file_count = len(re.findall(r'\w+\.\w+', desc))
        if file_count > 3:
            complexity_score += 2
            estimation['factors'].append(f'{file_count} fichiers affectés')
        
        # Check for testing requirements
        if 'test' in full_text:
            complexity_score += 1
            estimation['factors'].append('Tests requis')
        
        # Determine final complexity
        if complexity_score <= 0:
            estimation['complexity'] = 'low'
            estimation['estimated_hours'] = 0.5
            estimation['confidence'] = 0.8
        elif complexity_score <= 3:
            estimation['complexity'] = 'medium'
            estimation['estimated_hours'] = 2
            estimation['confidence'] = 0.7
        else:
            estimation['complexity'] = 'high'
            estimation['estimated_hours'] = 4
            estimation['confidence'] = 0.6
        
        # Adjust based on checklist items
        if task.get('checklists'):
            total_items = sum(len(cl['checkItems']) for cl in task['checklists'])
            if total_items > 5:
                estimation['estimated_hours'] *= 1.5
                estimation['factors'].append(f'{total_items} critères à satisfaire')
        
        return estimation
    
    def prioritize_tasks(self, tasks: List[Dict]) -> List[Dict]:
        """
        Prioritize tasks based on multiple factors
        """
        # Filter out system cards
        real_tasks = self.filter_real_tasks(tasks)
        prioritized = []
        
        for task in real_tasks:
            if task.get('list') in ['done', 'in_progress']:
                continue
            
            priority_score = 0
            factors = []
            
            # Check labels for priority
            labels = task.get('labels', [])
            for label in labels:
                if 'urgent' in label.get('name', '').lower() or label.get('color') == 'red':
                    priority_score += 10
                    factors.append('Marqué urgent')
                elif 'high' in label.get('name', '').lower() or label.get('color') == 'orange':
                    priority_score += 5
                    factors.append('Priorité haute')
            
            # Check for blocking keywords
            desc = task.get('desc', '').lower()
            if any(word in desc for word in ['bloque', 'blocking', 'critique', 'urgent']):
                priority_score += 8
                factors.append('Bloquant identifié')
            
            # Check dependencies
            dependencies = self.find_dependencies(task, real_tasks)
            if dependencies:
                # This task blocks others
                blocked_count = sum(1 for t in real_tasks if task['id'] in self.find_dependencies(t, real_tasks))
                if blocked_count > 0:
                    priority_score += blocked_count * 3
                    factors.append(f'Bloque {blocked_count} autres tâches')
            
            # Bug fixes get higher priority
            if 'bug' in task.get('name', '').lower() or 'fix' in task.get('name', '').lower():
                priority_score += 4
                factors.append('Correction de bug')
            
            # Due date
            if task.get('due'):
                due_date = datetime.fromisoformat(task['due'].replace('Z', '+00:00'))
                days_until_due = (due_date - datetime.utcnow()).days
                
                if days_until_due < 0:
                    priority_score += 15
                    factors.append('En retard!')
                elif days_until_due < 3:
                    priority_score += 10
                    factors.append(f'Échéance dans {days_until_due} jours')
                elif days_until_due < 7:
                    priority_score += 5
                    factors.append(f'Échéance proche')
            
            # Add task with metadata
            task_with_priority = task.copy()
            task_with_priority['priority_score'] = priority_score
            task_with_priority['priority_factors'] = factors
            prioritized.append(task_with_priority)
        
        # Sort by priority score
        prioritized.sort(key=lambda x: x['priority_score'], reverse=True)
        
        return prioritized

def format_analysis(analyzer: TaskAnalyzer, tasks: List[Dict]) -> str:
    """Format analysis results for display"""
    # Filter real tasks (exclude documentation)
    real_tasks = analyzer.filter_real_tasks(tasks)
    system_tasks = [t for t in tasks if analyzer.is_system_card(t)]
    
    output = []
    output.append("\n" + "="*60)
    output.append("📊 ANALYSE DU BOARD MISY")
    output.append("="*60)
    
    # Statistics
    stats = {
        'total': len(real_tasks),
        'backlog': sum(1 for t in real_tasks if t.get('list') == 'backlog'),
        'todo': sum(1 for t in real_tasks if t.get('list') == 'todo'),
        'in_progress': sum(1 for t in real_tasks if t.get('list') == 'in_progress'),
        'done': sum(1 for t in real_tasks if t.get('list') == 'done'),
        'system': len(system_tasks)
    }
    
    output.append(f"\n📈 Vue d'ensemble:")
    output.append(f"   Total: {stats['total']} tâches")
    output.append(f"   Backlog: {stats['backlog']}")
    output.append(f"   À faire: {stats['todo']}")
    output.append(f"   En cours: {stats['in_progress']}")
    output.append(f"   Terminées: {stats['done']}")
    if stats['system'] > 0:
        output.append(f"   📖 Documentation: {stats['system']} cartes (ignorées)")
    
    # Priority tasks
    prioritized = analyzer.prioritize_tasks(real_tasks)
    output.append(f"\n🎯 Tâches Prioritaires:")
    
    for i, task in enumerate(prioritized[:5]):
        if task['priority_score'] > 0:
            output.append(f"\n{i+1}. {task['name']} ({task['id']})")
            output.append(f"   Score: {task['priority_score']}")
            output.append(f"   Raisons: {', '.join(task['priority_factors'])}")
            
            # Add complexity estimation
            estimation = analyzer.estimate_complexity(task)
            output.append(f"   Complexité: {estimation['complexity']} (~{estimation['estimated_hours']}h)")
    
    # Tasks needing clarification
    unclear_tasks = []
    for task in real_tasks:
        if task.get('list') not in ['done', 'in_progress']:
            clarity_score, issues = analyzer.analyze_clarity(task)
            if clarity_score < 0.7:
                unclear_tasks.append((task, clarity_score, issues))
    
    if unclear_tasks:
        output.append(f"\n⚠️  Tâches Nécessitant Clarification:")
        for task, score, issues in unclear_tasks[:3]:
            output.append(f"\n- {task['name']} ({task['id']})")
            output.append(f"  Score clarté: {score:.1f}/1.0")
            output.append(f"  Problèmes: {', '.join(issues)}")
    
    # Grouping suggestions
    groups = analyzer.suggest_grouping(real_tasks)
    if groups:
        output.append(f"\n🔗 Suggestions de Regroupement:")
        for i, group in enumerate(groups[:3]):
            group_tasks = [t for t in real_tasks if t['id'] in group]
            names = [t['name'] for t in group_tasks]
            output.append(f"\n{i+1}. Groupe suggéré:")
            for name, task_id in zip(names, group):
                output.append(f"   - {name} ({task_id})")
    
    # Total time estimation
    total_hours = 0
    for task in prioritized:
        if task.get('list') not in ['done', 'in_progress']:
            estimation = analyzer.estimate_complexity(task)
            total_hours += estimation['estimated_hours']
    
    output.append(f"\n⏱️  Estimation Totale:")
    output.append(f"   ~{total_hours:.1f} heures de travail")
    output.append(f"   ({total_hours/8:.1f} jours à 8h/jour)")
    
    output.append("\n" + "="*60)
    
    return '\n'.join(output)

def main():
    """CLI interface for task analyzer"""
    if len(sys.argv) < 2:
        print("Usage: task_analyzer.py COMMAND")
        sys.exit(1)
    
    command = sys.argv[1]
    analyzer = TaskAnalyzer()
    
    if command == 'analyze':
        # Load tasks from board state
        tasks = analyzer.board_state.get('tasks', [])
        
        if not tasks:
            print("❌ No tasks found. Please run sync first.")
            sys.exit(1)
        
        # Perform analysis
        print(format_analysis(analyzer, tasks))
        
        # Save analysis results
        analysis = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'prioritized_ids': [t['id'] for t in analyzer.prioritize_tasks(tasks)[:10]],
            'unclear_tasks': [t['id'] for t, _, _ in 
                            [(t, *analyzer.analyze_clarity(t)) for t in tasks]
                            if analyzer.analyze_clarity(t)[0] < 0.7],
            'suggested_groups': analyzer.suggest_grouping(tasks)
        }
        
        with open(os.path.join(analyzer.data_dir, 'analysis.json'), 'w') as f:
            json.dump(analysis, f, indent=2)
    
    elif command == 'group':
        if len(sys.argv) < 4:
            print("❌ Two task IDs required")
            sys.exit(1)
        
        task1_id = sys.argv[2]
        task2_id = sys.argv[3]
        
        print(f"💡 Suggestion de regroupement pour {task1_id} et {task2_id}:")
        print(f"\nCes tâches pourraient être traitées ensemble car elles:")
        print("- Touchent des modules similaires")
        print("- Peuvent partager du code ou des tests")
        print("- Réduiraient le temps total de développement")
        print(f"\n✅ Ajoutez un label 'grouped-with-{task1_id}' sur les deux tâches dans Trello")

if __name__ == '__main__':
    main()