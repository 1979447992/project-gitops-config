#!/bin/bash
# ============================================================
# SIT 环境完整部署脚本
# ============================================================

set -e

echo "🚀 开始部署 SIT 环境..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 步骤: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_step "检查前置条件..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
    
    # Check if DEV environment exists
    if ! kubectl get namespace argocd &> /dev/null; then
        print_warning "未检测到 DEV 环境，建议先部署 DEV 环境"
    else
        print_success "检测到 DEV 环境存在"
    fi
    
    print_success "前置条件检查通过"
}

# Function to install SIT ArgoCD  
install_sit_argocd() {
    print_step "安装 SIT 环境 ArgoCD..."
    
    # Create argocd-sit namespace for independent SIT instance
    kubectl create namespace argocd-sit --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD in SIT namespace
    kubectl apply -n argocd-sit -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    print_step "等待 SIT ArgoCD 组件启动..."
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd-sit
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-repo-server -n argocd-sit
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-dex-server -n argocd-sit
    
    print_success "SIT ArgoCD 安装完成"
}

# Function to configure SIT ArgoCD access
configure_sit_argocd_access() {
    print_step "配置 SIT ArgoCD 访问..."
    
    # Patch SIT ArgoCD server service to use NodePort 30089
    kubectl patch svc argocd-server -n argocd-sit -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"targetPort":8080,"nodePort":30089,"protocol":"TCP"}]}}'
    
    # Disable TLS for easier access (development only)
    kubectl patch configmap argocd-cmd-params-cm -n argocd-sit --type merge -p '{"data":{"server.insecure":"true"}}'
    
    # Set custom admin password for SIT
    kubectl delete secret argocd-initial-admin-secret -n argocd-sit --ignore-not-found=true
    kubectl create secret generic argocd-initial-admin-secret -n argocd-sit --from-literal=password=sitadmin123
    
    # Restart argocd-server to apply changes
    kubectl rollout restart deployment/argocd-server -n argocd-sit
    kubectl wait --for=condition=Available --timeout=120s deployment/argocd-server -n argocd-sit
    
    print_success "SIT ArgoCD 访问配置完成"
}

# Function to deploy SIT applications
deploy_sit_applications() {
    print_step "部署 SIT 环境应用..."
    
    # Apply SIT App of Apps (this will use argocd-sit namespace)
    sed 's/namespace: argocd/namespace: argocd-sit/' argocd/app-of-apps.yaml | kubectl apply -f -
    
    print_step "等待应用同步..."
    sleep 30  # Give ArgoCD time to process
    
    print_success "SIT 应用部署完成"
}

# Function to get SIT access information
get_sit_access_info() {
    print_step "获取 SIT 访问信息..."
    
    # Get cluster node IPs
    echo ""
    echo "=== 集群节点信息 ==="
    kubectl get nodes -o wide --no-headers | awk '{print $1 " : " $7}' || kubectl get nodes -o wide
    
    # Get SIT ArgoCD password
    echo ""
    echo "=== SIT ArgoCD 访问信息 ==="
    
    echo "🌐 SIT ArgoCD 访问地址: http://NODE_IP:30089"
    echo "👤 用户名: admin"
    echo "🔑 密码: sitadmin123"
    
    # Get service status
    echo ""
    echo "=== SIT ArgoCD 服务状态 ==="
    kubectl get svc -n argocd-sit argocd-server
}

# Function to verify SIT deployment
verify_sit_deployment() {
    print_step "验证 SIT 环境部署..."
    
    echo ""
    echo "=== SIT ArgoCD Pods 状态 ==="
    kubectl get pods -n argocd-sit
    
    echo ""
    echo "=== SIT ArgoCD 应用状态 ==="
    kubectl get applications -n argocd-sit 2>/dev/null || echo "应用尚未创建或正在同步中"
    
    echo ""
    echo "=== SIT 微服务命名空间状态 ==="
    kubectl get namespace | grep -E "(microservice.*sit|monitoring-sit)" || echo "SIT 微服务命名空间尚未创建"
    
    # Check if any pods exist in SIT microservice namespaces
    for ns in microservice1-sit microservice2-sit monitoring-sit; do
        echo "--- $ns 命名空间 ---"
        kubectl get pods -n $ns 2>/dev/null || echo "$ns 命名空间尚未创建或无 Pods"
    done
}

# Function to show environment comparison
show_environment_comparison() {
    print_step "环境对比..."
    
    echo ""
    echo "=== 环境对比 ==="
    echo "| 环境 | ArgoCD 命名空间 | 访问端口 | Git 分支 |"
    echo "|------|-----------------|----------|----------|"
    echo "| DEV  | argocd          | 30080    | dev      |"
    echo "| SIT  | argocd-sit      | 30089    | sit      |"
    
    echo ""
    echo "=== 命名空间状态对比 ==="
    echo "--- DEV 环境命名空间 ---"
    kubectl get namespace | grep -E "(argocd$|microservice.*dev|monitoring$)" || echo "DEV 命名空间未找到"
    
    echo "--- SIT 环境命名空间 ---"
    kubectl get namespace | grep -E "(argocd-sit|microservice.*sit|monitoring-sit)" || echo "SIT 命名空间未找到"
}

# Main deployment process
main() {
    echo "=========================================="
    echo "      SIT 环境部署脚本"
    echo "=========================================="
    
    check_prerequisites
    install_sit_argocd
    configure_sit_argocd_access
    deploy_sit_applications
    
    echo ""
    get_sit_access_info
    echo ""
    verify_sit_deployment
    echo ""
    show_environment_comparison
    
    echo ""
    print_success "🎉 SIT 环境部署完成！"
    echo ""
    echo "📚 下一步:"
    echo "  1. 使用 http://NODE_IP:30089 和密码 sitadmin123 登录 SIT ArgoCD"
    echo "  2. 验证所有 SIT 应用都在同步状态"
    echo "  3. 确认 DEV 和 SIT 环境完全独立"
    echo "  4. 等待 SIT 微服务和监控组件完成部署"
}

# Script usage
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "用法: $0"
    echo ""
    echo "这个脚本将完整部署 SIT 环境，包括:"
    echo "  - 独立的 SIT ArgoCD 安装 (argocd-sit 命名空间)"
    echo "  - NodePort 30089 访问配置"
    echo "  - SIT 应用部署"
    echo "  - 与 DEV 环境的隔离验证"
    exit 0
fi

# Run main function
main "$@"