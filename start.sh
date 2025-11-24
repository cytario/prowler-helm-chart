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
CHART_PATH="./charts/prowler"
AUTO_YES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-y|--yes]"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Prowler Helm Chart Installer${NC}"
echo -e "${BLUE}================================${NC}\n"

# Check if microk8s is running
echo -e "${YELLOW}[1/7]${NC} Checking microk8s status..."
if ! microk8s status --wait-ready > /dev/null 2>&1; then
    echo -e "${RED}ERROR: microk8s is not running${NC}"
    echo "Start it with: microk8s start"
    exit 1
fi
echo -e "${GREEN}✓${NC} microk8s is running\n"

# Check required addons
echo -e "${YELLOW}[2/7]${NC} Checking required microk8s addons..."
ENABLED_ADDONS=$(microk8s status | awk '/enabled:/,/disabled:/' | grep -E "^\s+[a-z]")
MISSING_ADDONS=""

# Check DNS
if ! echo "$ENABLED_ADDONS" | grep -q "^\s*dns\s"; then
    MISSING_ADDONS="${MISSING_ADDONS}dns "
else
    echo -e "  ${GREEN}✓${NC} dns is enabled"
fi

# Check storage (hostpath-storage or storage)
if ! echo "$ENABLED_ADDONS" | grep -qE "^\s*(hostpath-storage|storage)\s"; then
    MISSING_ADDONS="${MISSING_ADDONS}hostpath-storage "
else
    echo -e "  ${GREEN}✓${NC} storage is available"
fi

# Check helm3
if ! echo "$ENABLED_ADDONS" | grep -q "^\s*helm3\s"; then
    MISSING_ADDONS="${MISSING_ADDONS}helm3 "
else
    echo -e "  ${GREEN}✓${NC} helm3 is enabled"
fi

# Handle missing addons
if [ -n "$MISSING_ADDONS" ]; then
    echo -e "${YELLOW}⚠${NC}  Missing addons: ${MISSING_ADDONS}"
    echo "Enable them with: sudo microk8s enable ${MISSING_ADDONS}"
    if [ "$AUTO_YES" = false ]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "Continuing anyway (--yes flag)"
    fi
fi
echo ""

# Create namespace
echo -e "${YELLOW}[3/7]${NC} Creating namespace '$NAMESPACE'..."
if microk8s kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Namespace '$NAMESPACE' already exists\n"
else
    microk8s kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓${NC} Namespace '$NAMESPACE' created\n"
fi

# Update Helm dependencies
echo -e "${YELLOW}[4/7]${NC} Updating Helm chart dependencies..."
cd $CHART_PATH
helm dependency update
cd - > /dev/null
echo -e "${GREEN}✓${NC} Dependencies updated\n"

# Check if release already exists
echo -e "${YELLOW}[5/7]${NC} Checking for existing release..."
if microk8s helm list -n $NAMESPACE | grep -q "^$RELEASE_NAME"; then
    echo -e "${YELLOW}⚠${NC}  Release '$RELEASE_NAME' already exists"
    if [ "$AUTO_YES" = false ]; then
        read -p "Do you want to upgrade it? (y/N): " -n 1 -r
        echo
    else
        REPLY="y"
        echo "Upgrading automatically (--yes flag)"
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Upgrading release..."

        # Check if storage class exists
        if ! microk8s kubectl get storageclass &> /dev/null || [ $(microk8s kubectl get storageclass -o name | wc -l) -eq 0 ]; then
            echo -e "${YELLOW}⚠${NC}  No StorageClass found - using emptyDir"
            STORAGE_OPTS="--set postgresql.primary.persistence.enabled=false --set valkey.dataStorage.enabled=false"
        else
            echo -e "${GREEN}✓${NC} StorageClass available - using persistent storage"
            STORAGE_OPTS=""
        fi

        microk8s helm upgrade $RELEASE_NAME $CHART_PATH \
            --namespace $NAMESPACE \
            --set postgresql.global.postgresql.auth.postgresPassword="prowler_secure_password" \
            $STORAGE_OPTS \
            --wait
        echo -e "${GREEN}✓${NC} Release upgraded successfully\n"
    else
        echo "Skipping installation"
        exit 0
    fi
else
    # Install the chart
    echo -e "${YELLOW}[6/7]${NC} Installing Prowler Helm chart..."

    # Check if storage class exists
    if ! microk8s kubectl get storageclass &> /dev/null || [ $(microk8s kubectl get storageclass -o name | wc -l) -eq 0 ]; then
        echo -e "${YELLOW}⚠${NC}  No StorageClass found - installing with emptyDir"
        echo "    - PostgreSQL: emptyDir (database data will be lost on pod restart)"
        echo "    - Valkey: emptyDir (cache data will be lost on pod restart)"
        echo "    - Shared scan output: emptyDir (scan results will be lost on pod restart)"
        echo ""
        echo "For persistent storage, enable: sudo microk8s enable hostpath-storage"
        STORAGE_OPTS="--set postgresql.primary.persistence.enabled=false --set valkey.dataStorage.enabled=false"
        # Note: sharedStorage defaults to emptyDir, no need to set it explicitly
    else
        echo -e "${GREEN}✓${NC} StorageClass available - using persistent storage"
        echo "    - PostgreSQL: PersistentVolumeClaim"
        echo "    - Valkey: PersistentVolumeClaim"
        echo "    - Shared scan output: emptyDir (upgrade to PVC with: --set sharedStorage.type=persistentVolumeClaim)"
        STORAGE_OPTS=""
        # Note: For production, consider enabling persistent shared storage:
        # STORAGE_OPTS="--set sharedStorage.type=persistentVolumeClaim"
    fi

    microk8s helm install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --set postgresql.global.postgresql.auth.postgresPassword="prowler_secure_password" \
        $STORAGE_OPTS \
        --wait \
        --timeout 10m
    echo -e "${GREEN}✓${NC} Chart installed successfully\n"
fi

# Show deployment status
echo -e "${YELLOW}[7/7]${NC} Checking deployment status..."
echo ""
microk8s kubectl get pods -n $NAMESPACE
echo ""

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
microk8s kubectl wait --for=condition=ready pod \
    --selector=app.kubernetes.io/instance=$RELEASE_NAME \
    --namespace=$NAMESPACE \
    --timeout=600s 2>/dev/null || true
echo ""

# Show services
echo -e "${BLUE}Services:${NC}"
microk8s kubectl get svc -n $NAMESPACE
echo ""

# Run Helm tests
echo -e "${YELLOW}Running Helm tests...${NC}"
if microk8s helm test $RELEASE_NAME -n $NAMESPACE; then
    echo -e "${GREEN}✓${NC} All tests passed\n"
else
    echo -e "${YELLOW}⚠${NC}  Some tests failed (this is normal if pods are still starting)\n"
fi

# Show access instructions
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Installation Complete!${NC}"
echo -e "${BLUE}================================${NC}\n"

UI_PORT=$(microk8s kubectl get svc -n $NAMESPACE ${RELEASE_NAME}-ui -o jsonpath='{.spec.ports[0].port}')
API_PORT=$(microk8s kubectl get svc -n $NAMESPACE ${RELEASE_NAME}-api -o jsonpath='{.spec.ports[0].port}')

echo -e "${GREEN}Prowler has been successfully deployed!${NC}\n"

echo -e "${YELLOW}To access the UI:${NC}"
echo "  microk8s kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-ui ${UI_PORT}:${UI_PORT}"
echo -e "  Then open: ${GREEN}http://localhost:${UI_PORT}${NC}\n"

echo -e "${YELLOW}To access the API:${NC}"
echo "  microk8s kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-api ${API_PORT}:${API_PORT}"
echo -e "  Then open: ${GREEN}http://localhost:${API_PORT}/api/v1/docs${NC}\n"

echo -e "${YELLOW}Useful commands:${NC}"
echo "  View logs:          ./logs.sh"
echo "  Get pods:           microk8s kubectl get pods -n $NAMESPACE"
echo "  Get PVCs:           microk8s kubectl get pvc -n $NAMESPACE"
echo "  Uninstall:          ./stop.sh"
echo ""

echo -e "${YELLOW}Storage configuration:${NC}"
if microk8s kubectl get pvc -n $NAMESPACE 2>/dev/null | grep -q "shared-storage"; then
    echo "  Shared scan output: PersistentVolumeClaim (persistent)"
else
    echo "  Shared scan output: emptyDir (temporary)"
    echo "  To enable persistent scan storage, upgrade with:"
    echo "    microk8s helm upgrade $RELEASE_NAME $CHART_PATH -n $NAMESPACE --set sharedStorage.type=persistentVolumeClaim"
fi
echo ""

# Offer to start port-forwarding
if [ "$AUTO_YES" = false ]; then
    read -p "Do you want to start port-forwarding for the UI now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Starting port-forward...${NC}"
        echo -e "Access the UI at: ${GREEN}http://localhost:${UI_PORT}${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"
        microk8s kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-ui ${UI_PORT}:${UI_PORT}
    fi
else
    echo -e "${BLUE}Skipping port-forward (--yes flag)${NC}"
    echo "To start port-forwarding manually, run:"
    echo "  microk8s kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-ui ${UI_PORT}:${UI_PORT}"
fi
