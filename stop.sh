#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="prowler"
RELEASE_NAME="prowler"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Prowler Helm Chart Uninstaller${NC}"
echo -e "${BLUE}================================${NC}\n"

# Check if microk8s is running
echo -e "${YELLOW}Checking microk8s status...${NC}"
if ! microk8s status --wait-ready > /dev/null 2>&1; then
    echo -e "${RED}ERROR: microk8s is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} microk8s is running\n"

# Check if namespace exists
if ! microk8s kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  Namespace '$NAMESPACE' does not exist"
    echo "Nothing to uninstall"
    exit 0
fi

# Check if release exists
if ! microk8s helm list -n $NAMESPACE | grep -q "^$RELEASE_NAME"; then
    echo -e "${YELLOW}⚠${NC}  Release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
    read -p "Do you want to delete the namespace anyway? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting namespace...${NC}"
        microk8s kubectl delete namespace $NAMESPACE
        echo -e "${GREEN}✓${NC} Namespace deleted\n"
    fi
    exit 0
fi

# Show current resources
echo -e "${BLUE}Current resources in namespace '$NAMESPACE':${NC}"
microk8s kubectl get all -n $NAMESPACE
echo ""

# Confirm uninstall
read -p "Are you sure you want to uninstall Prowler? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

# Uninstall the release
echo -e "${YELLOW}Uninstalling Helm release...${NC}"
microk8s helm uninstall $RELEASE_NAME -n $NAMESPACE
echo -e "${GREEN}✓${NC} Release uninstalled\n"

# Ask to delete namespace
read -p "Do you want to delete the namespace '$NAMESPACE'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deleting namespace...${NC}"
    microk8s kubectl delete namespace $NAMESPACE --timeout=60s
    echo -e "${GREEN}✓${NC} Namespace deleted\n"
else
    echo -e "${YELLOW}⚠${NC}  Namespace '$NAMESPACE' was kept"
    echo "You can delete it manually with: microk8s kubectl delete namespace $NAMESPACE"
    echo ""
fi

# Ask to delete PVCs
echo -e "${YELLOW}Checking for persistent volume claims...${NC}"
PVCS=$(microk8s kubectl get pvc --all-namespaces -o json | grep -c "prowler" || true)
if [ "$PVCS" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC}  Found $PVCS PVC(s) related to Prowler"
    microk8s kubectl get pvc --all-namespaces | grep prowler || true
    echo ""
    read -p "Do you want to delete these PVCs? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        microk8s kubectl get pvc --all-namespaces -o json | \
            jq -r '.items[] | select(.metadata.name | contains("prowler")) |
            "kubectl delete pvc \(.metadata.name) -n \(.metadata.namespace)"' | \
            while read cmd; do
                echo "Executing: $cmd"
                eval "microk8s $cmd"
            done
        echo -e "${GREEN}✓${NC} PVCs deleted\n"
    fi
fi

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}  Uninstall Complete!${NC}"
echo -e "${BLUE}================================${NC}\n"

echo "Prowler has been successfully uninstalled from your cluster."
