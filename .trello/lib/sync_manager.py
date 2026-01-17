#!/usr/bin/env python3
"""
Sync Manager for Misy Project
Manages synchronization between Trello and local state
"""

import json
import os
import sys
import re
from datetime import datetime
from typing import Dict, List, Any

# Import the Trello client
sys.path.append(os.path.dirname(__file__))
from trello_client import TrelloClient

class SyncManager:
    """Manages synchronization between Trello and local state"""
    
    def __init__(self, config_path: str = None, data_dir: str = None):
        """Initialize sync manager"""
        if data_dir is None:
            data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
        
        self.data_dir = data_dir
        self.board_state_file = os.path.join(data_dir, 'board_state.json')
        self.client = TrelloClient(config_path)
        
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
        
        # Ensure data directory exists
        os.makedirs(data_dir, exist_ok=True)
    
    def get_list_mapping(self) -> Dict[str, str]:
        """Get mapping of list IDs to list names"""
        lists = self.client.get_lists()
        return {lst['id']: lst['name'] for lst in lists}
    
    def _is_system_card(self, card: Dict) -> bool:
        """
        Determine if a card is a system/documentation card
        """
        card_name = card.get('name', '')
        
        # Check against patterns
        for pattern in self.system_card_patterns:
            if re.match(pattern, card_name, re.IGNORECASE):
                return True
        
        # Check for documentation keywords in description
        desc = card.get('desc', '').lower()
        doc_keywords = ['exemple', 'template', 'guide', 'documentation', 'explication']
        
        if any(keyword in desc for keyword in doc_keywords) and len(desc) > 500:
            return True
        
        return False
    
    def sync(self) -> Dict[str, Any]:
        """
        Perform full synchronization with Trello
        Returns sync summary
        """
        print("🔄 Starting synchronization...")
        
        try:
            # Get board info
            board = self.client.get_board()
            print(f"📋 Board: {board['name']}")
            
            # Get all lists
            lists = self.client.get_lists()
            list_mapping = {lst['id']: lst['name'] for lst in lists}
            
            # Get all cards
            all_cards = self.client.get_cards()
            print(f"📊 Found {len(all_cards)} cards")
            
            # Process cards
            tasks = []
            for card in all_cards:
                # Get detailed card info if needed
                task = {
                    'id': card['id'],
                    'name': card['name'],
                    'desc': card.get('desc', ''),
                    'list': self._map_list_name(list_mapping.get(card['idList'], 'unknown')),
                    'list_id': card['idList'],
                    'labels': card.get('labels', []),
                    'due': card.get('due'),
                    'due_complete': card.get('dueComplete', False),
                    'last_activity': card.get('dateLastActivity'),
                    'checklists': card.get('checklists', []),
                    'url': card.get('shortUrl', f"https://trello.com/c/{card['id']}"),
                    'is_system': self._is_system_card(card)
                }
                tasks.append(task)
            
            # Sort tasks by list and activity
            tasks.sort(key=lambda x: (x['list'], x['last_activity'] or ''), reverse=True)
            
            # Prepare board state
            board_state = {
                'board_id': board['id'],
                'board_name': board['name'],
                'last_sync': datetime.utcnow().isoformat() + 'Z',
                'lists': lists,
                'list_mapping': list_mapping,
                'tasks': tasks,
                'stats': {
                    'total': len(tasks),
                    'by_list': {}
                }
            }
            
            # Calculate stats by list
            for list_name in set(task['list'] for task in tasks):
                board_state['stats']['by_list'][list_name] = sum(1 for t in tasks if t['list'] == list_name)
            
            # Save board state
            with open(self.board_state_file, 'w', encoding='utf-8') as f:
                json.dump(board_state, f, ensure_ascii=False, indent=2)
            
            # Print summary
            print("\n✅ Synchronization complete!")
            print(f"\n📈 Summary:")
            for list_name, count in board_state['stats']['by_list'].items():
                print(f"   {list_name}: {count} tasks")
            
            return {
                'success': True,
                'total_tasks': len(tasks),
                'stats': board_state['stats']
            }
            
        except Exception as e:
            print(f"\n❌ Synchronization failed: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def _map_list_name(self, list_name: str) -> str:
        """Map Trello list names to standard names"""
        # This mapping helps standardize list names
        mapping = {
            'backlog': 'backlog',
            'à faire': 'todo',
            'todo': 'todo',
            'en cours': 'in_progress',
            'in progress': 'in_progress',
            'à valider': 'testing',
            'validation': 'testing',
            'terminé': 'done',
            'done': 'done',
            'completed': 'done'
        }
        
        # Try to find a match
        lower_name = list_name.lower()
        for key, value in mapping.items():
            if key in lower_name:
                return value
        
        # Return original if no match
        return list_name.lower().replace(' ', '_')
    
    def get_board_state(self) -> Dict[str, Any]:
        """Get current board state from local cache"""
        if os.path.exists(self.board_state_file):
            with open(self.board_state_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        return None
    
    def incremental_sync(self, since: str = None) -> Dict[str, Any]:
        """
        Perform incremental sync (only updated cards)
        Not implemented in basic version - falls back to full sync
        """
        print("ℹ️  Incremental sync not implemented, performing full sync...")
        return self.sync()

def main():
    """CLI interface for sync manager"""
    if len(sys.argv) < 2:
        print("Usage: sync_manager.py COMMAND")
        sys.exit(1)
    
    command = sys.argv[1]
    sync_manager = SyncManager()
    
    if command == 'sync':
        result = sync_manager.sync()
        
        if not result['success']:
            sys.exit(1)
    
    elif command == 'status':
        board_state = sync_manager.get_board_state()
        
        if not board_state:
            print("❌ No board state found. Please run sync first.")
            sys.exit(1)
        
        last_sync = board_state.get('last_sync', 'Never')
        print(f"\n📊 Board Status")
        print(f"Board: {board_state.get('board_name', 'Unknown')}")
        print(f"Last sync: {last_sync}")
        print(f"Total tasks: {board_state['stats']['total']}")
        
        print("\nTasks by list:")
        for list_name, count in board_state['stats']['by_list'].items():
            print(f"  {list_name}: {count}")
    
    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)

if __name__ == '__main__':
    main()