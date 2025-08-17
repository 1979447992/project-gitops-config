#!/bin/bash
# ============================================================
# 环境清理脚本 - 删除所有ArgoCD相关资源
# ============================================================

set -e

echo "🧹 开始清理所有环境..."

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

# Function to check kubectl
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装 kubectl"
        echo ""
        echo "Windows 安装方法:"
        echo "1. choco install kubernetes-cli"
        echo "2. scoop install kubectl"
        echo "3. 手动下载: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
        exit 1
    fi
    
    print_success "kubectl 已安装"
}

# Function to clean up all environments
cleanup_environments() {
    print_step "删除 ArgoCD 相关命名空间..."
    
    # Delete ArgoCD namespaces
    kubectl delete namespace argocd --ignore-not-found=true
    kubectl delete namespace argocd-sit --ignore-not-found=true
    
    # Delete microservice namespaces
    kubectl delete namespace microservice1-dev --ignore-not-found=true
    kubectl delete namespace microservice2-dev --ignore-not-found=true
    kubectl delete namespace microservice1-sit --ignore-not-found=true
    kubectl delete namespace microservice2-sit --ignore-not-found=true
    
    # Delete monitoring namespaces
    kubectl delete namespace monitoring --ignore-not-found=true
    kubectl delete namespace monitoring-sit --ignore-not-found=true
    
    print_step "等待命名空间完全删除..."
    kubectl wait --for=delete namespace/argocd --timeout=60s 2>/dev/null || true
    kubectl wait --for=delete namespace/argocd-sit --timeout=60s 2>/dev/null || true
    
    print_success "环境清理完成"
}

# Function to verify cleanup
verify_cleanup() {
    print_step "验证清理结果..."
    
    echo ""
    echo "=== 剩余的相关命名空间 ==="
    kubectl get namespaces | grep -E "(argocd|microservice|monitoring)" || echo "✅ 所有相关命名空间已删除"
    
    echo ""
    echo "=== 剩余的 CRD ==="
    kubectl get crd | grep argoproj || echo "✅ ArgoCD CRD 已删除"
}

# Main cleanup process
main() {
    echo "=========================================="
    echo "      环境清理脚本"
    echo "=========================================="
    
    check_kubectl
    
    print_warning "即将删除所有 ArgoCD 相关资源"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "清理已取消"
        exit 1
    fi
    
    cleanup_environments
    verify_cleanup
    
    echo ""
    print_success "🎉 环境清理完成！现在可以重新部署。"
}

# Run main function
main "$@"