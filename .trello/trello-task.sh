#!/bin/bash

# Trello Task Management System for Misy Project
# Main entry point for all Trello operations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
DATA_DIR="${SCRIPT_DIR}/data"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
REPORTS_DIR="${SCRIPT_DIR}/reports"

# Ensure data directory exists
mkdir -p "${DATA_DIR}" "${REPORTS_DIR}"

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if config exists
check_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        print_error "Configuration file not found!"
        print_info "Please run: $0 setup"
        exit 1
    fi
}

# Setup configuration
setup() {
    print_info "Setting up Trello integration..."
    
    # Check for Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed."
        exit 1
    fi
    
    # Install Python dependencies
    print_info "Installing Python dependencies..."
    if command -v pip3 &> /dev/null; then
        pip3 install requests python-dateutil --quiet
    elif python3 -m pip --version &> /dev/null; then
        python3 -m pip install requests python-dateutil --quiet
    else
        print_warning "pip not found, attempting to install..."
        sudo apt update && sudo apt install -y python3-pip
        pip3 install requests python-dateutil --quiet
    fi
    
    # Get Trello API credentials
    echo ""
    print_info "You'll need your Trello API key and token."
    print_info "Get them from: https://trello.com/app-key"
    echo ""
    
    read -p "Enter your Trello API Key: " api_key
    read -p "Enter your Trello Token: " token
    read -p "Enter your Board ID (or board name): " board_id
    
    # Create config file
    cat > "${CONFIG_FILE}" <<EOF
{
    "api_key": "${api_key}",
    "token": "${token}",
    "board_id": "${board_id}",
    "lists": {
        "backlog": "Backlog",
        "todo": "À faire",
        "in_progress": "En cours",
        "testing": "À valider",
        "done": "Terminé"
    }
}
EOF
    
    chmod 600 "${CONFIG_FILE}"
    print_success "Configuration saved!"
    
    # Initial sync
    sync
}

# Sync with Trello
sync() {
    check_config
    print_info "Synchronizing with Trello..."
    
    python3 "${LIB_DIR}/sync_manager.py" sync
    
    if [[ $? -eq 0 ]]; then
        print_success "Synchronization complete!"
        
        # Update last sync time
        echo "{\"last_sync\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "${DATA_DIR}/last_sync.json"
    else
        print_error "Synchronization failed!"
        exit 1
    fi
}

# Analyze tasks
analyze() {
    check_config
    print_info "Analyzing tasks..."
    
    # Check if we need to sync first
    if [[ -f "${DATA_DIR}/last_sync.json" ]]; then
        last_sync=$(python3 -c "import json; print(json.load(open('${DATA_DIR}/last_sync.json'))['last_sync'])")
        hours_since=$(python3 -c "
from datetime import datetime, timezone
last = datetime.fromisoformat('${last_sync}'.replace('Z', '+00:00'))
now = datetime.now(timezone.utc)
print(int((now - last).total_seconds() / 3600))
")
        
        if [[ $hours_since -gt 2 ]]; then
            print_warning "Last sync was ${hours_since} hours ago. Syncing first..."
            sync
        fi
    else
        sync
    fi
    
    python3 "${LIB_DIR}/task_analyzer.py" analyze
}

# List tasks
list_tasks() {
    check_config
    local status="${1:-all}"
    
    python3 "${LIB_DIR}/trello_client.py" list "${status}"
}

# Get specific task
get_task() {
    check_config
    local task_id="$1"
    
    if [[ -z "${task_id}" ]]; then
        print_error "Task ID required!"
        echo "Usage: $0 get TASK_ID"
        exit 1
    fi
    
    python3 "${LIB_DIR}/trello_client.py" get "${task_id}"
}

# Request clarification
clarify() {
    check_config
    local task_id="$1"
    local message="$2"
    
    if [[ -z "${task_id}" ]] || [[ -z "${message}" ]]; then
        print_error "Task ID and message required!"
        echo "Usage: $0 clarify TASK_ID \"Your clarification message\""
        exit 1
    fi
    
    python3 "${LIB_DIR}/trello_client.py" clarify "${task_id}" "${message}"
}

# Complete task (move to validation)
complete() {
    check_config
    local task_id="$1"
    local summary="${2:-Task completed}"
    
    if [[ -z "${task_id}" ]]; then
        print_error "Task ID required!"
        echo "Usage: $0 complete TASK_ID [summary]"
        exit 1
    fi
    
    # Generate report
    report_file="${REPORTS_DIR}/report_${task_id}_$(date +%Y%m%d_%H%M%S).md"
    python3 "${LIB_DIR}/report_generator.py" generate "${task_id}" "${summary}" > "${report_file}"
    
    # Update Trello - move to validation instead of done
    python3 "${LIB_DIR}/trello_client.py" complete "${task_id}" "${report_file}" "testing"
    
    print_success "Task ${task_id} moved to validation!"
    print_info "Report saved to: ${report_file}"
    print_warning "Task requires validation before being marked as done."
}

# Validate task (move to done)
validate() {
    check_config
    local task_id="$1"
    local validation_note="${2:-Task validated}"
    
    if [[ -z "${task_id}" ]]; then
        print_error "Task ID required!"
        echo "Usage: $0 validate TASK_ID [validation_note]"
        exit 1
    fi
    
    # Move to done
    python3 "${LIB_DIR}/trello_client.py" validate "${task_id}" "${validation_note}"
    
    print_success "Task ${task_id} validated and marked as done!"
    print_info "Validation note: ${validation_note}"
}

# Group tasks
group() {
    check_config
    local task1="$1"
    local task2="$2"
    
    if [[ -z "${task1}" ]] || [[ -z "${task2}" ]]; then
        print_error "Two task IDs required!"
        echo "Usage: $0 group TASK_ID1 TASK_ID2"
        exit 1
    fi
    
    python3 "${LIB_DIR}/task_analyzer.py" group "${task1}" "${task2}"
}

# Show help
show_help() {
    cat << EOF
Trello Task Management System for Misy Project

Usage: $0 COMMAND [OPTIONS]

Commands:
    setup               Initial setup and configuration
    sync                Synchronize with Trello board
    analyze             Analyze tasks and show priorities
    list [status]       List tasks (all, backlog, todo, in_progress, testing, done)
    get TASK_ID         Get details for a specific task
    clarify TASK_ID "message"   Request clarification on a task
    complete TASK_ID [summary]  Mark task as complete and move to validation
    validate TASK_ID [note]     Validate task and mark as done
    group TASK_ID1 TASK_ID2     Suggest grouping two tasks
    help                Show this help message

Examples:
    $0 setup                    # Initial configuration
    $0 sync                     # Sync with Trello
    $0 analyze                  # Get task analysis and priorities
    $0 list todo                # List all todo tasks
    $0 get MISY-101             # Get details for task MISY-101
    $0 clarify MISY-101 "What are the expected performance metrics?"
    $0 complete MISY-101 "Fixed timeout issue with retry logic"
    $0 validate MISY-101 "Tested and works correctly"

EOF
}

# Main command handler
case "${1:-help}" in
    setup)
        setup
        ;;
    sync)
        sync
        ;;
    analyze)
        analyze
        ;;
    list)
        list_tasks "${2:-all}"
        ;;
    get)
        get_task "${2:-}"
        ;;
    clarify)
        clarify "${2:-}" "${3:-}"
        ;;
    complete)
        complete "${2:-}" "${3:-}"
        ;;
    validate)
        validate "${2:-}" "${3:-}"
        ;;
    group)
        group "${2:-}" "${3:-}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac