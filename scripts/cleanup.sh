#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="wordpress"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_status() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

confirm_cleanup() {
    echo -e "${YELLOW}This will delete the entire WordPress-MySQL deployment.${NC}"
    echo -e "${YELLOW}This action cannot be undone!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
}

cleanup_application() {
    print_header "Cleaning up WordPress Application"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        kubectl delete namespace "$NAMESPACE"
        print_status "Namespace '$NAMESPACE' deletion initiated"
    else
        print_warning "Namespace '$NAMESPACE' not found"
    fi

    echo "Waiting for namespace to be fully deleted..."
    while kubectl get namespace "$NAMESPACE" &> /dev/null; do
        sleep 2
    done
    print_status "Namespace fully deleted"
}

cleanup_storage() {
    print_header "Cleaning up Persistent Volumes (if any)"

    FOUND_PVS=$(kubectl get pv -o jsonpath='{.items[*].metadata.name}' | grep -E "mysql-pv|wordpress-pv" || true)

    if [[ -n "$FOUND_PVS" ]]; then
        for pv in $FOUND_PVS; do
            kubectl delete pv "$pv"
            print_status "Deleted PV: $pv"
        done
    else
        print_warning "No MySQL or WordPress PVs found"
    fi
}

cleanup_dashboard() {
    print_header "Cleaning up Kubernetes Dashboard"

    read -p "Do you want to remove Kubernetes Dashboard? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml || true
        print_status "Kubernetes Dashboard deleted"
    else
        print_status "Kubernetes Dashboard kept"
    fi
}

cleanup_temp_files() {
    print_header "Cleaning up Temporary Files"

    if [ -f "/tmp/wordpress-deployment.yaml" ]; then
        rm /tmp/wordpress-deployment.yaml
        print_status "Temporary deployment file removed"
    fi
}

main() {
    print_header "WordPress-MySQL Cleanup"

    confirm_cleanup
    cleanup_application
    cleanup_storage
    cleanup_dashboard
    cleanup_temp_files

    print_header "Cleanup Complete!"
    print_status "All WordPress-MySQL resources have been removed"
    echo ""
    echo "Note: If you used NFS, any data on the server still persists."
    echo "Remove manually if needed: /nfs/mysql and /nfs/wordpress"
}

main
