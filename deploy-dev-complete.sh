#!/bin/bash
# ============================================================
# DEV 环境完整部署脚本
# ============================================================

set -e

echo "🚀 开始部署 DEV 环境..."

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
        echo "请先安装 kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群"
        echo "请确保集群正在运行且 kubeconfig 配置正确"
        exit 1
    fi
    
    print_success "前置条件检查通过"
}

# Function to install ArgoCD
install_argocd() {
    print_step "安装 ArgoCD 到 DEV 环境..."
    
    # Create argocd namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    print_step "等待 ArgoCD 组件启动..."
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-repo-server -n argocd
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-dex-server -n argocd
    
    print_success "ArgoCD 安装完成"
}

# Function to configure ArgoCD access
configure_argocd_access() {
    print_step "配置 ArgoCD 访问..."
    
    # Patch ArgoCD server service to use NodePort 30080
    kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"targetPort":8080,"nodePort":30080,"protocol":"TCP"}]}}'
    
    # Disable TLS for easier access (development only)
    kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
    
    # Restart argocd-server to apply changes
    kubectl rollout restart deployment/argocd-server -n argocd
    kubectl wait --for=condition=Available --timeout=120s deployment/argocd-server -n argocd
    
    print_success "ArgoCD 访问配置完成"
}

# Function to deploy DEV applications
deploy_dev_applications() {
    print_step "部署 DEV 环境应用..."
    
    # Apply DEV App of Apps
    kubectl apply -f argocd/app-of-apps.yaml
    
    print_step "等待应用同步..."
    sleep 30  # Give ArgoCD time to process
    
    print_success "DEV 应用部署完成"
}

# Function to get access information
get_access_info() {
    print_step "获取访问信息..."
    
    # Get cluster node IPs
    echo ""
    echo "=== 集群节点信息 ==="
    kubectl get nodes -o wide --no-headers | awk '{print $1 " : " $7}' || kubectl get nodes -o wide
    
    # Get ArgoCD initial password
    echo ""
    echo "=== ArgoCD 访问信息 ==="
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "密码获取失败")
    
    echo "🌐 ArgoCD 访问地址: http://NODE_IP:30080"
    echo "👤 用户名: admin"
    echo "🔑 密码: $ARGOCD_PASSWORD"
    
    # Get service status
    echo ""
    echo "=== ArgoCD 服务状态 ==="
    kubectl get svc -n argocd argocd-server
}

# Function to verify deployment
verify_deployment() {
    print_step "验证 DEV 环境部署..."
    
    echo ""
    echo "=== ArgoCD Pods 状态 ==="
    kubectl get pods -n argocd
    
    echo ""
    echo "=== ArgoCD 应用状态 ==="
    kubectl get applications -n argocd 2>/dev/null || echo "应用尚未创建或正在同步中"
    
    echo ""
    echo "=== 微服务命名空间状态 ==="
    kubectl get namespace | grep -E "(microservice|monitoring)" || echo "微服务命名空间尚未创建"
    
    # Check if any pods exist in microservice namespaces
    for ns in microservice1-dev microservice2-dev monitoring; do
        echo "--- $ns 命名空间 ---"
        kubectl get pods -n $ns 2>/dev/null || echo "$ns 命名空间尚未创建或无 Pods"
    done
}

# Main deployment process
main() {
    echo "=========================================="
    echo "      DEV 环境部署脚本"
    echo "=========================================="
    
    check_prerequisites
    install_argocd
    configure_argocd_access
    deploy_dev_applications
    
    echo ""
    get_access_info
    echo ""
    verify_deployment
    
    echo ""
    print_success "🎉 DEV 环境部署完成！"
    echo ""
    echo "📚 下一步:"
    echo "  1. 使用上面提供的地址和密码登录 ArgoCD"
    echo "  2. 验证所有应用都在同步状态"
    echo "  3. 等待微服务和监控组件完成部署"
    echo "  4. 确认 DEV 环境工作正常后，可以部署 SIT 环境"
}

# Script usage
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "用法: $0"
    echo ""
    echo "这个脚本将完整部署 DEV 环境，包括:"
    echo "  - ArgoCD 安装和配置"
    echo "  - NodePort 30080 访问配置"
    echo "  - DEV 应用部署"
    echo "  - 部署验证"
    exit 0
fi

# Run main function
main "$@"