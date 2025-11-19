#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="prowler"
RELEASE_NAME="prowler"

# Function to show menu
show_menu() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Prowler Logs Viewer${NC}"
    echo -e "${BLUE}================================${NC}\n"
    echo "Select component to view logs:"
    echo "  1) API"
    echo "  2) UI"
    echo "  3) Worker"
    echo "  4) Worker Beat"
    echo "  5) PostgreSQL"
    echo "  6) Valkey"
    echo "  7) All components (split screen)"
    echo "  0) Exit"
    echo ""
}

# Function to view logs
view_logs() {
    local component=$1
    local label=$2

    echo -e "${GREEN}Viewing logs for: ${component}${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"

    microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=${RELEASE_NAME}-${label} -f --tail=50
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice: " choice
    echo ""

    case $choice in
        1)
            view_logs "API" "api"
            ;;
        2)
            view_logs "UI" "ui"
            ;;
        3)
            view_logs "Worker" "worker"
            ;;
        4)
            view_logs "Worker Beat" "worker-beat"
            ;;
        5)
            echo -e "${GREEN}Viewing PostgreSQL logs${NC}"
            echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"
            microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=postgresql -f --tail=50
            ;;
        6)
            echo -e "${GREEN}Viewing Valkey logs${NC}"
            echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"
            microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=valkey -f --tail=50
            ;;
        7)
            if ! command -v tmux &> /dev/null; then
                echo -e "${RED}ERROR: tmux is not installed${NC}"
                echo "Install it with: sudo apt install tmux"
                read -p "Press Enter to continue..."
                continue
            fi

            echo -e "${GREEN}Starting split screen view...${NC}"
            echo -e "${YELLOW}Use Ctrl+B then arrow keys to switch panes${NC}"
            echo -e "${YELLOW}Use Ctrl+B then 'd' to detach${NC}"
            sleep 2

            tmux new-session -d -s prowler-logs "microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=${RELEASE_NAME}-api -f --tail=20"
            tmux split-window -h "microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=${RELEASE_NAME}-ui -f --tail=20"
            tmux split-window -v "microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=${RELEASE_NAME}-worker -f --tail=20"
            tmux select-pane -t 0
            tmux split-window -v "microk8s kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=${RELEASE_NAME}-worker-beat -f --tail=20"
            tmux attach-session -t prowler-logs
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            sleep 2
            ;;
    esac

    echo ""
    read -p "Press Enter to return to menu..."
    clear
done
