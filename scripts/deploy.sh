#!/bin/bash
# scripts/deploy.sh - WordPress + MySQL Deployment on Kubernetes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
NAMESPACE="wordpress"
MYSQL_PASSWORD="mysqlpass"

print_header() {
    echo -e "${BLUE}========== $1 ==========${NC}"
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

check_prerequisites() {
    print_header "Checking Prerequisites"

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found"
        exit 1
    fi
    print_status "kubectl is installed"

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_status "Cluster is accessible"
}

create_namespace() {
    print_header "Ensuring Namespace Exists"
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    print_status "Namespace '$NAMESPACE' ready"
}

create_secrets() {
    print_header "Creating Secret"

    kubectl delete secret mysql-pass -n "$NAMESPACE" --ignore-not-found=true

    kubectl create secret generic mysql-pass \
        --from-literal=password="$MYSQL_PASSWORD" \
        -n "$NAMESPACE"

    print_status "Secret 'mysql-pass' created"
}

deploy_components() {
    print_header "Deploying WordPress and MySQL"

    kubectl apply -f mysql.yaml -n "$NAMESPACE"
    kubectl apply -f wordpress.yaml -n "$NAMESPACE"

    print_status "YAMLs applied"
}

wait_for_deployments() {
    print_header "Waiting for Deployments"

    echo "Waiting for MySQL..."
    kubectl rollout status deployment/mysql -n "$NAMESPACE" --timeout=300s

    echo "Waiting for WordPress..."
    kubectl rollout status deployment/wordpress -n "$NAMESPACE" --timeout=300s

    print_status "Deployments ready"
}

display_access_info() {
    print_header "Access Info"

    NODE_PORT=$(kubectl get svc wordpress -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

    echo -e "${GREEN}Access WordPress at: http://$NODE_IP:$NODE_PORT${NC}"
    echo ""
    echo -e "${YELLOW}If not working, try port-forward:${NC}"
    echo "kubectl port-forward svc/wordpress 8080:80 -n $NAMESPACE"
    echo "Access at: http://localhost:8080"
}

main() {
    print_header "🚀 WordPress + MySQL Deployment"

    check_prerequisites
    create_namespace
    create_secrets
    deploy_components
    wait_for_deployments
    display_access_info

    print_header "✅ Deployment Complete!"
}

main
