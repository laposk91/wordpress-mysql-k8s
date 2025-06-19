# scripts/verify.sh - Deployment Verification Script
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

check_namespace() {
    print_header "Checking Namespace"
    
    if kubectl get namespace wordpress-mysql &> /dev/null; then
        print_status "Namespace wordpress-mysql exists"
    else
        print_error "Namespace wordpress-mysql not found"
        return 1
    fi
}

check_secrets() {
    print_header "Checking Secrets"
    
    if kubectl get secret mysql-secret -n wordpress-mysql &> /dev/null; then
        print_status "MySQL secret exists"
    else
        print_error "MySQL secret not found"
        return 1
    fi
}

check_storage() {
    print_header "Checking Storage"
    
    # Check PVs
    PV_COUNT=$(kubectl get pv | grep -c "mysql-pv\|wordpress-pv" || echo "0")
    if [ "$PV_COUNT" -eq 2 ]; then
        print_status "Persistent Volumes are created"
    else
        print_warning "Expected 2 PVs, found $PV_COUNT"
    fi
    
    # Check PVCs
    kubectl get pvc -n wordpress-mysql
    PVC_BOUND=$(kubectl get pvc -n wordpress-mysql -o jsonpath='{.items[*].status.phase}' | grep -o "Bound" | wc -l)
    if [ "$PVC_BOUND" -eq 2 ]; then
        print_status "All PVCs are bound"
    else
        print_warning "Not all PVCs are bound"
    fi
}

check_deployments() {
    print_header "Checking Deployments"
    
    # Check MySQL deployment
    MYSQL_READY=$(kubectl get deployment mysql -n wordpress-mysql -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$MYSQL_READY" -eq 1 ]; then
        print_status "MySQL deployment is ready"
    else
        print_error "MySQL deployment is not ready"
    fi
    
    # Check WordPress deployment
    WP_READY=$(kubectl get deployment wordpress -n wordpress-mysql -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    WP_DESIRED=$(kubectl get deployment wordpress -n wordpress-mysql -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [ "$WP_READY" -eq "$WP_DESIRED" ]; then
        print_status "WordPress deployment is ready ($WP_READY/$WP_DESIRED replicas)"
    else
        print_warning "WordPress deployment: $WP_READY/$WP_DESIRED replicas ready"
    fi
}

check_services() {
    print_header "Checking Services"
    
    # Check MySQL service
    if kubectl get service mysql-service -n wordpress-mysql &> /dev/null; then
        print_status "MySQL service exists"
        
        # Check endpoints
        MYSQL_ENDPOINTS=$(kubectl get endpoints mysql-service -n wordpress-mysql -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo "0")
        if [ "$MYSQL_ENDPOINTS" -gt 0 ]; then
            print_status "MySQL service has endpoints"
        else
            print_warning "MySQL service has no endpoints"
        fi
    else
        print_error "MySQL service not found"
    fi
    
    # Check WordPress service
    if kubectl get service wordpress-service -n wordpress-mysql &> /dev/null; then
        print_status "WordPress service exists"
        
        # Check external access
        EXTERNAL_IP=$(kubectl get svc wordpress-service -n wordpress-mysql -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ]; then
            print_status "WordPress service has external IP: $EXTERNAL_IP"
        else
            print_warning "WordPress service does not have external IP assigned"
        fi
    else
        print_error "WordPress service not found"
    fi
}

check_pod_health() {
    print_header "Checking Pod Health"
    
    echo "Current pod status:"
    kubectl get pods -n wordpress-mysql
    
    # Check MySQL pod health
    MYSQL_POD=$(kubectl get pods -n wordpress-mysql -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$MYSQL_POD" ]; then
        if kubectl exec -n wordpress-mysql "$MYSQL_POD" -- mysqladmin ping -h localhost --silent; then
            print_status "MySQL is responding to ping"
        else
            print_error "MySQL is not responding to ping"
        fi
    fi
    
    # Check WordPress pod health
    WP_POD=$(kubectl get pods -n wordpress-mysql -l app=wordpress -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$WP_POD" ]; then
        HTTP_CODE=$(kubectl exec -n wordpress-mysql "$WP_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost/wp-admin/install.php || echo "000")
        if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 302 ]; then
            print_status "WordPress is responding to HTTP requests"
        else
            print_warning "WordPress HTTP response code: $HTTP_CODE"
        fi
    fi
}

check_connectivity() {
    print_header "Checking Database Connectivity"
    
    # Test database connection from WordPress pod
    WP_POD=$(kubectl get pods -n wordpress-mysql -l app=wordpress -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$WP_POD" ]; then
        if kubectl exec -n wordpress-mysql "$WP_POD" -- ping -c 1 mysql-service &> /dev/null; then
            print_status "WordPress can ping MySQL service"
        else
            print_error "WordPress cannot ping MySQL service"
        fi
    fi
}

check_resources() {
    print_header "Checking Resource Usage"
    
    echo "Resource quotas:"
    kubectl describe quota wordpress-quota -n wordpress-mysql
    
    echo ""
    echo "Pod resource usage:"
    kubectl top pods -n wordpress-mysql 2>/dev/null || print_warning "Metrics server not available"
}

display_logs() {
    print_header "Recent Logs"
    
    echo "MySQL logs (last 10 lines):"
    kubectl logs -n wordpress-mysql deployment/mysql --tail=10
    
    echo ""
    echo "WordPress logs (last 10 lines):"
    kubectl logs -n wordpress-mysql deployment/wordpress --tail=10
}

main() {
    print_header "WordPress-MySQL Deployment Verification"
    
    check_namespace || exit 1
    check_secrets || exit 1
    check_storage
    check_deployments
    check_services
    check_pod_health
    check_connectivity
    check_resources
    display_logs
    
    print_header "Verification Complete"
    echo "If all checks passed, your WordPress deployment is healthy!"
}

# Run main function
main


