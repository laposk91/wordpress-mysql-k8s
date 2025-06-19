# scripts/cleanup.sh - Cleanup Script
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    # Delete namespace (this will delete all resources in the namespace)
    if kubectl get namespace wordpress-mysql &> /dev/null; then
        kubectl delete namespace wordpress-mysql
        print_status "WordPress namespace deleted"
    else
        print_warning "WordPress namespace not found"
    fi
    
    # Wait for namespace to be fully deleted
    echo "Waiting for namespace to be fully deleted..."
    while kubectl get namespace wordpress-mysql &> /dev/null; do
        sleep 2
    done
    print_status "Namespace fully deleted"
}

cleanup_storage() {
    print_header "Cleaning up Storage"
    
    # Delete Persistent Volumes
    if kubectl get pv mysql-pv &> /dev/null; then
        kubectl delete pv mysql-pv
        print_status "MySQL PV deleted"
    else
        print_warning "MySQL PV not found"
    fi
    
    if kubectl get pv wordpress-pv &> /dev/null; then
        kubectl delete pv wordpress-pv
        print_status "WordPress PV deleted"
    else
        print_warning "WordPress PV not found"
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
    echo "Note: NFS data may still exist on your NFS server."
    echo "Remove manually if needed: /nfs/mysql and /nfs/wordpress"
}

# Run main function
main
