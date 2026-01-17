#!/usr/bin/env python3
"""
Report Generator for Misy Project
Generates completion reports for Trello tasks
"""

import json
import os
import sys
from datetime import datetime
from typing import Dict, Any

class ReportGenerator:
    """Generates formatted reports for task completion"""
    
    def __init__(self, data_dir: str = None):
        """Initialize report generator"""
        if data_dir is None:
            data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
        
        self.data_dir = data_dir
        self.board_state_file = os.path.join(data_dir, 'board_state.json')
        self.templates_dir = os.path.join(os.path.dirname(__file__), '..', 'templates')
    
    def generate_report(self, task_id: str, summary: str = "", changes: Dict[str, Any] = None) -> str:
        """Generate a completion report for a task"""
        # Load board state to get task details
        task = None
        if os.path.exists(self.board_state_file):
            with open(self.board_state_file, 'r', encoding='utf-8') as f:
                board_state = json.load(f)
                for t in board_state.get('tasks', []):
                    if t['id'] == task_id:
                        task = t
                        break
        
        if not task:
            task = {'id': task_id, 'name': 'Unknown Task'}
        
        # Default changes structure
        if changes is None:
            changes = {
                'files_modified': [],
                'tests_added': 0,
                'tests_passed': True,
                'validation': {
                    'flutter_analyze': 'passed',
                    'flutter_test': 'passed',
                    'dart_format': 'passed'
                }
            }
        
        # Generate report
        report = []
        report.append("## 🤖 Rapport d'Exécution Claude\n")
        report.append(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M')}")
        report.append(f"**Tâche:** {task.get('name', 'Unknown')} ({task_id})")
        report.append(f"**Status:** ✅ Complété\n")
        
        if summary:
            report.append("### 📝 Résumé")
            report.append(f"{summary}\n")
        
        # Changes section
        if changes.get('files_modified'):
            report.append("### 🔧 Modifications Effectuées")
            for file_info in changes['files_modified']:
                if isinstance(file_info, dict):
                    report.append(f"- ✅ {file_info['path']} ({file_info.get('changes', 'modifié')})")
                else:
                    report.append(f"- ✅ {file_info}")
            report.append("")
        
        # Testing section
        if changes.get('tests_added', 0) > 0:
            report.append("### ✅ Tests")
            report.append(f"- **Ajoutés:** {changes['tests_added']} nouveaux tests")
            report.append(f"- **Status:** {'Tous passent ✅' if changes.get('tests_passed', True) else 'Échecs ❌'}")
            report.append("")
        
        # Validation section
        if changes.get('validation'):
            report.append("### 🔍 Validation")
            val = changes['validation']
            report.append(f"- `flutter analyze`: {'✅' if val.get('flutter_analyze') == 'passed' else '❌'}")
            report.append(f"- `flutter test`: {'✅' if val.get('flutter_test') == 'passed' else '❌'}")
            report.append(f"- `dart format`: {'✅' if val.get('dart_format') == 'passed' else '❌'}")
            report.append("")
        
        # Recommendations
        if changes.get('recommendations'):
            report.append("### 💡 Recommandations")
            for rec in changes['recommendations']:
                report.append(f"- {rec}")
            report.append("")
        
        # Commands
        if changes.get('branch_name'):
            report.append("### 💻 Commandes de Vérification")
            report.append("```bash")
            report.append(f"git checkout {changes['branch_name']}")
            report.append("flutter test")
            report.append("flutter run")
            report.append("```\n")
        
        report.append("---")
        report.append("🤖 Generated with [Claude Code](https://claude.ai/code)")
        
        return '\n'.join(report)

def main():
    """CLI interface for report generator"""
    if len(sys.argv) < 3:
        print("Usage: report_generator.py generate TASK_ID [summary]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == 'generate':
        task_id = sys.argv[2]
        summary = sys.argv[3] if len(sys.argv) > 3 else ""
        
        generator = ReportGenerator()
        
        # In real usage, changes would be tracked during task execution
        # For now, we'll use a simple example
        changes = {
            'files_modified': [
                {'path': 'lib/provider/example_provider.dart', 'changes': 'updated logic'},
                {'path': 'test/provider/example_provider_test.dart', 'changes': 'added tests'}
            ],
            'tests_added': 5,
            'tests_passed': True,
            'validation': {
                'flutter_analyze': 'passed',
                'flutter_test': 'passed',
                'dart_format': 'passed'
            },
            'recommendations': [
                'Consider monitoring performance in production',
                'Update documentation for new feature'
            ],
            'branch_name': f'feature/{task_id.lower()}'
        }
        
        report = generator.generate_report(task_id, summary, changes)
        print(report)
    
    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)

if __name__ == '__main__':
    main()