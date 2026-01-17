#!/usr/bin/env python3
"""
Trello API Client for Misy Project
Handles all direct interactions with Trello API
"""

import json
import os
import sys
import requests
from datetime import datetime
from typing import Dict, List, Optional, Any

class TrelloClient:
    """Client for interacting with Trello API"""
    
    def __init__(self, config_path: str = None):
        """Initialize Trello client with configuration"""
        if config_path is None:
            config_path = os.path.join(os.path.dirname(__file__), '..', 'config.json')
        
        with open(config_path, 'r') as f:
            self.config = json.load(f)
        
        self.api_key = self.config['api_key']
        self.token = self.config['token']
        self.board_id = self.config['board_id']
        self.base_url = 'https://api.trello.com/1'
        
        # Get board ID if name was provided
        if len(self.board_id) != 24:  # Trello IDs are 24 characters long
            self.board_id = self._get_board_id_by_name(self.board_id)
    
    def _get_board_id_by_name(self, board_name: str) -> str:
        """Get board ID from board name"""
        url = f'{self.base_url}/members/me/boards'
        params = {'key': self.api_key, 'token': self.token}
        
        response = requests.get(url, params=params)
        boards = response.json()
        
        for board in boards:
            if board['name'].lower() == board_name.lower():
                return board['id']
        
        raise ValueError(f"Board '{board_name}' not found")
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> Any:
        """Make authenticated request to Trello API"""
        url = f'{self.base_url}{endpoint}'
        params = kwargs.get('params', {})
        params.update({'key': self.api_key, 'token': self.token})
        kwargs['params'] = params
        
        response = requests.request(method, url, **kwargs)
        response.raise_for_status()
        return response.json() if response.text else None
    
    def get_board(self) -> Dict:
        """Get board information"""
        return self._make_request('GET', f'/boards/{self.board_id}')
    
    def get_lists(self) -> List[Dict]:
        """Get all lists on the board"""
        return self._make_request('GET', f'/boards/{self.board_id}/lists')
    
    def get_cards(self, list_id: Optional[str] = None) -> List[Dict]:
        """Get cards from board or specific list"""
        if list_id:
            endpoint = f'/lists/{list_id}/cards'
        else:
            endpoint = f'/boards/{self.board_id}/cards'
        
        params = {
            'fields': 'name,desc,labels,idList,dateLastActivity,due,dueComplete',
            'attachments': 'false',
            'members': 'false',
            'checklists': 'all'
        }
        
        return self._make_request('GET', endpoint, params=params)
    
    def get_card(self, card_id: str) -> Dict:
        """Get detailed information about a specific card"""
        params = {
            'fields': 'all',
            'attachments': 'true',
            'members': 'true',
            'checklists': 'all',
            'actions': 'commentCard,updateCard',
            'actions_limit': '10'
        }
        
        return self._make_request('GET', f'/cards/{card_id}', params=params)
    
    def add_comment(self, card_id: str, comment: str) -> Dict:
        """Add a comment to a card"""
        data = {'text': comment}
        return self._make_request('POST', f'/cards/{card_id}/actions/comments', data=data)
    
    def update_card(self, card_id: str, **kwargs) -> Dict:
        """Update card properties"""
        return self._make_request('PUT', f'/cards/{card_id}', data=kwargs)
    
    def move_card(self, card_id: str, list_id: str) -> Dict:
        """Move card to different list"""
        return self.update_card(card_id, idList=list_id)
    
    def add_label(self, card_id: str, label_id: str) -> Dict:
        """Add label to card"""
        return self._make_request('POST', f'/cards/{card_id}/idLabels', data={'value': label_id})
    
    def get_labels(self) -> List[Dict]:
        """Get all labels for the board"""
        return self._make_request('GET', f'/boards/{self.board_id}/labels')
    
    def create_label(self, name: str, color: str = 'green') -> Dict:
        """Create a new label"""
        data = {'name': name, 'color': color}
        return self._make_request('POST', f'/boards/{self.board_id}/labels', data=data)
    
    def create_card(self, name: str, desc: str = '', idList: str = None, **kwargs) -> Dict:
        """Create a new card"""
        data = {
            'name': name,
            'desc': desc,
            'idList': idList,
            **kwargs
        }
        # Remove None values
        data = {k: v for k, v in data.items() if v is not None}
        return self._make_request('POST', '/cards', data=data)
    
    def get_board_actions(self, limit: int = 50, filter_actions: str = 'all') -> List[Dict]:
        """Get actions from the board"""
        params = {
            'limit': limit,
            'filter': filter_actions,
            'fields': 'all',
            'member': 'true',
            'memberCreator': 'true'
        }
        return self._make_request('GET', f'/boards/{self.board_id}/actions', params=params)

def format_card_output(card: Dict) -> str:
    """Format card for console output"""
    output = []
    output.append(f"\n📋 {card['name']}")
    output.append(f"ID: {card['id']}")
    
    if card.get('desc'):
        output.append(f"\nDescription:\n{card['desc']}")
    
    if card.get('labels'):
        labels = [f"{label['name']} ({label['color']})" for label in card['labels']]
        output.append(f"\nLabels: {', '.join(labels)}")
    
    if card.get('due'):
        due_date = datetime.fromisoformat(card['due'].replace('Z', '+00:00'))
        output.append(f"\nDue: {due_date.strftime('%Y-%m-%d %H:%M')}")
    
    if card.get('checklists'):
        for checklist in card['checklists']:
            output.append(f"\n✅ {checklist['name']}:")
            for item in checklist['checkItems']:
                status = '☑' if item['state'] == 'complete' else '☐'
                output.append(f"  {status} {item['name']}")
    
    return '\n'.join(output)

def main():
    """CLI interface for Trello client"""
    if len(sys.argv) < 2:
        print("Usage: trello_client.py COMMAND [ARGS]")
        sys.exit(1)
    
    command = sys.argv[1]
    client = TrelloClient()
    
    try:
        if command == 'list':
            status = sys.argv[2] if len(sys.argv) > 2 else 'all'
            
            # Get all lists
            lists = client.get_lists()
            list_map = {lst['name'].lower(): lst['id'] for lst in lists}
            
            # Get cards
            if status == 'all':
                cards = client.get_cards()
            else:
                list_names = client.config.get('lists', {})
                list_name = list_names.get(status, status)
                list_id = list_map.get(list_name.lower())
                
                if not list_id:
                    print(f"❌ List '{list_name}' not found")
                    sys.exit(1)
                
                cards = client.get_cards(list_id)
            
            if not cards:
                print("No cards found")
            else:
                for card in cards:
                    print(format_card_output(card))
                    print("-" * 50)
        
        elif command == 'get':
            if len(sys.argv) < 3:
                print("❌ Task ID required")
                sys.exit(1)
            
            card_id = sys.argv[2]
            card = client.get_card(card_id)
            print(format_card_output(card))
            
            # Save to current task file
            data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
            with open(os.path.join(data_dir, 'current_task.md'), 'w') as f:
                f.write(f"# Task: {card['name']}\n\n")
                f.write(f"**ID:** {card['id']}\n")
                f.write(f"**URL:** {card['shortUrl']}\n\n")
                
                if card.get('desc'):
                    f.write(f"## Description\n\n{card['desc']}\n\n")
                
                if card.get('checklists'):
                    f.write("## Acceptance Criteria\n\n")
                    for checklist in card['checklists']:
                        f.write(f"### {checklist['name']}\n\n")
                        for item in checklist['checkItems']:
                            status = 'x' if item['state'] == 'complete' else ' '
                            f.write(f"- [{status}] {item['name']}\n")
                        f.write("\n")
            
            print(f"\n✅ Task saved to data/current_task.md")
        
        elif command == 'clarify':
            if len(sys.argv) < 4:
                print("❌ Task ID and message required")
                sys.exit(1)
            
            card_id = sys.argv[2]
            message = sys.argv[3]
            
            # Add clarification label if not exists
            labels = client.get_labels()
            clarification_label = next((l for l in labels if l['name'] == 'needs-clarification'), None)
            
            if not clarification_label:
                clarification_label = client.create_label('needs-clarification', 'yellow')
            
            # Add label to card
            try:
                client.add_label(card_id, clarification_label['id'])
            except:
                pass  # Label might already be there
            
            # Add comment
            comment = f"🤔 **Clarification Needed:**\n\n{message}"
            client.add_comment(card_id, comment)
            
            print(f"✅ Clarification request added to task {card_id}")
        
        elif command == 'complete':
            if len(sys.argv) < 3:
                print("❌ Task ID required")
                sys.exit(1)
            
            card_id = sys.argv[2]
            report_file = sys.argv[3] if len(sys.argv) > 3 else None
            target_list = sys.argv[4] if len(sys.argv) > 4 else 'done'
            
            # Read report if provided
            if report_file and os.path.exists(report_file):
                with open(report_file, 'r') as f:
                    report = f.read()
                client.add_comment(card_id, report)
            
            # Move to target list (testing for validation, done for final completion)
            lists = client.get_lists()
            target_list_name = client.config.get('lists', {}).get(target_list, 'Terminé')
            target_list_obj = next((l for l in lists if l['name'] == target_list_name), None)
            
            if target_list_obj:
                client.move_card(card_id, target_list_obj['id'])
                status = "moved to validation" if target_list == 'testing' else "marked as complete"
                print(f"✅ Task {card_id} {status}")
            else:
                print(f"⚠️  Could not find '{target_list_name}' list. Task commented but not moved.")
        
        elif command == 'validate':
            if len(sys.argv) < 3:
                print("❌ Task ID required")
                sys.exit(1)
            
            card_id = sys.argv[2]
            validation_note = sys.argv[3] if len(sys.argv) > 3 else "Task validated and approved"
            
            # Add validation comment
            comment = f"✅ **Task Validated:**\n\n{validation_note}\n\n*Validated on {datetime.now().strftime('%Y-%m-%d %H:%M')}*"
            client.add_comment(card_id, comment)
            
            # Move to done list
            lists = client.get_lists()
            done_list_name = client.config.get('lists', {}).get('done', 'Terminé')
            done_list = next((l for l in lists if l['name'] == done_list_name), None)
            
            if done_list:
                client.move_card(card_id, done_list['id'])
                print(f"✅ Task {card_id} validated and marked as done")
            else:
                print(f"⚠️  Could not find 'done' list. Task commented but not moved.")
        
        else:
            print(f"❌ Unknown command: {command}")
            print("Available commands: list, get, clarify, complete, validate")
            sys.exit(1)
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main()