#!/bin/bash
# ============================================================
# DEV 环境部署脚本
# ============================================================
# 
# 📝 学习说明:
# 这个脚本专门用于部署 DEV 环境
# 每个环境分支都有自己的部署脚本，确保完全隔离
#
# 🔧 DEV 环境特点:
# - ArgoCD 命名空间: argocd
# - 访问端口: 30080
# - Git 分支: dev
# - 应用命名空间: microservice1-dev, microservice2-dev, monitoring
#
# 🌟 分支隔离优势:
# - 每个分支只包含自己环境的配置
# - 避免配置混乱和误操作
# - 符合企业级分支管理最佳实践
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

# Function to check if ArgoCD is installed
check_argocd() {
    print_step "检查 DEV ArgoCD 状态..."
    if kubectl get namespace argocd >/dev/null 2>&1; then
        print_success "ArgoCD 命名空间已存在"
    else
        print_warning "ArgoCD 命名空间不存在，请先安装 ArgoCD"
        echo "安装命令: kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
        exit 1
    fi
}

# Function to deploy DEV environment
deploy_dev_environment() {
    print_step "部署 DEV 环境应用..."
    
    # Deploy DEV App of Apps
    kubectl apply -f argocd/app-of-apps.yaml
    
    print_success "DEV 环境部署完成"
    echo "  🌐 DEV ArgoCD 访问地址: http://your-server-ip:30080"
    echo "  🔑 用户名: admin"
    echo "  🔑 密码: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Function to verify deployment
verify_deployment() {
    print_step "验证 DEV 环境部署状态..."
    
    echo ""
    echo "=== DEV 环境状态 ==="
    kubectl get applications -n argocd
    echo ""
    echo "=== DEV 环境 Pods ==="
    kubectl get pods -n microservice1-dev 2>/dev/null || echo "microservice1-dev 命名空间尚未创建"
    kubectl get pods -n microservice2-dev 2>/dev/null || echo "microservice2-dev 命名空间尚未创建"
    kubectl get pods -n monitoring 2>/dev/null || echo "monitoring 命名空间尚未创建"
    
    echo ""
    echo "=== DEV 环境服务访问地址 ==="
    echo "🔸 DEV ArgoCD:     http://your-server-ip:30080"
    echo "🔸 DEV Grafana:    http://your-server-ip:30081"
    echo "🔸 DEV Prometheus: http://your-server-ip:30090"
    echo "🔸 DEV AlertManager: http://your-server-ip:30093"
}

# Main deployment process
main() {
    echo "=========================================="
    echo "          DEV 环境部署脚本"
    echo "=========================================="
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    # Check ArgoCD
    check_argocd
    
    # Deploy DEV environment
    deploy_dev_environment
    
    echo ""
    verify_deployment
    
    echo ""
    print_success "🎉 DEV 环境部署完成！"
    echo ""
    echo "📚 后续操作建议:"
    echo "  1. 登录 DEV ArgoCD 验证应用状态"
    echo "  2. 检查微服务和监控组件运行状态"
    echo "  3. 访问 Grafana 查看监控数据"
}

# Script usage
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "用法: $0"
    echo ""
    echo "这个脚本用于部署 DEV 环境的所有组件"
    echo "包括 microservice1-dev, microservice2-dev 和 monitoring"
    exit 0
fi

# Run main function
main "$@"