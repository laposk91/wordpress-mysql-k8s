#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="wordpress"

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

check_namespace() {
    print_header "Checking Namespace"
    if kubectl get namespace $NAMESPACE &>/dev/null; then
        print_status "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' not found"
        return 1
    fi
}

check_secret() {
    print_header "Checking Secret"
    if kubectl get secret mysql-pass -n $NAMESPACE &>/dev/null; then
        print_status "Secret 'mysql-pass' exists"
    else
        print_error "Secret 'mysql-pass' not found"
    fi
}

check_deployments() {
    print_header "Checking Deployments"

    MYSQL_READY=$(kubectl get deployment mysql -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' || echo 0)
    if [ "$MYSQL_READY" -ge 1 ]; then
        print_status "MySQL deployment is ready"
    else
        print_error "MySQL deployment is not ready"
    fi

    WP_READY=$(kubectl get deployment wordpress -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' || echo 0)
    WP_DESIRED=$(kubectl get deployment wordpress -n $NAMESPACE -o jsonpath='{.spec.replicas}' || echo 0)
    if [ "$WP_READY" -eq "$WP_DESIRED" ]; then
        print_status "WordPress deployment is ready ($WP_READY/$WP_DESIRED replicas)"
    else
        print_warning "WordPress not fully ready ($WP_READY/$WP_DESIRED)"
    fi
}

check_services() {
    print_header "Checking Services"

    if kubectl get svc mysql -n $NAMESPACE &>/dev/null; then
        print_status "MySQL service exists"
    else
        print_error "MySQL service not found"
    fi

    if kubectl get svc wordpress -n $NAMESPACE &>/dev/null; then
        print_status "WordPress service exists"

        NODE_PORT=$(kubectl get svc wordpress -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo -e "${YELLOW}Try accessing WordPress at: http://$NODE_IP:$NODE_PORT${NC}"
    else
        print_error "WordPress service not found"
    fi
}

check_pod_health() {
    print_header "Checking Pod Health"
    kubectl get pods -n $NAMESPACE

    MYSQL_POD=$(kubectl get pods -n $NAMESPACE -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$MYSQL_POD" ]; then
        kubectl exec -n $NAMESPACE "$MYSQL_POD" -- mysqladmin ping -h localhost --silent &>/dev/null && \
            print_status "MySQL pod is healthy" || print_error "MySQL is not responding"
    fi

    WP_POD=$(kubectl get pods -n $NAMESPACE -l app=wordpress -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$WP_POD" ]; then
        CODE=$(kubectl exec -n $NAMESPACE "$WP_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost/wp-admin/install.php)
        if [[ "$CODE" == "200" || "$CODE" == "302" ]]; then
            print_status "WordPress responded with HTTP code $CODE"
        else
            print_warning "Unexpected HTTP response: $CODE"
        fi
    fi
}

check_connectivity() {
    print_header "Checking WordPress ↔ MySQL Connectivity"

    WP_POD=$(kubectl get pods -n $NAMESPACE -l app=wordpress -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$WP_POD" ]; then
        kubectl exec -n $NAMESPACE "$WP_POD" -- ping -c 1 mysql &>/dev/null && \
            print_status "WordPress can reach MySQL service" || print_error "Ping failed from WordPress to MySQL"
    fi
}

display_logs() {
    print_header "Recent Logs"

    echo -e "\nMySQL logs:"
    kubectl logs -n $NAMESPACE deployment/mysql --tail=10

    echo -e "\nWordPress logs:"
    kubectl logs -n $NAMESPACE deployment/wordpress --tail=10
}

main() {
    print_header "🚦 WordPress Deployment Verification"
    check_namespace || exit 1
    check_secret
    check_deployments
    check_services
    check_pod_health
    check_connectivity
    display_logs
    print_header "✅ Verification Complete"
    echo "If all checks passed, your deployment is healthy!"
}

main
