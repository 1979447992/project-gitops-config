#!/bin/bash
# ============================================================
# SIT 环境部署脚本
# ============================================================
# 
# 📝 学习说明:
# 这个脚本专门用于部署 SIT 环境
# 每个环境分支都有自己的部署脚本，确保完全隔离
#
# 🔧 SIT 环境特点:
# - ArgoCD 命名空间: argocd
# - 访问端口: 30089
# - Git 分支: sit
# - 应用命名空间: microservice1-sit, microservice2-sit, monitoring-sit
#
# 🌟 分支隔离优势:
# - 每个分支只包含自己环境的配置
# - 避免配置混乱和误操作
# - 符合企业级分支管理最佳实践
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

# Function to check if ArgoCD operator is installed
check_argocd_operator() {
    print_step "检查 ArgoCD Operator..."
    if kubectl get crd argocds.argoproj.io >/dev/null 2>&1; then
        print_success "ArgoCD Operator 已安装"
    else
        print_warning "ArgoCD Operator 未安装，正在安装..."
        kubectl create namespace argocd-operator-system --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://raw.githubusercontent.com/argoproj-labs/argocd-operator/v0.8.0/deploy/install.yaml
        print_success "ArgoCD Operator 安装完成"
    fi
}

# Function to deploy SIT environment
deploy_sit_environment() {
    print_step "部署 SIT 环境 ArgoCD 实例..."
    
    # Deploy SIT ArgoCD instance
    kubectl apply -f argocd/argocd-install.yaml
    
    # Wait for SIT ArgoCD to be ready
    print_step "等待 SIT ArgoCD 就绪..."
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd
    
    # Deploy SIT App of Apps
    kubectl apply -f argocd/app-of-apps.yaml
    
    print_success "SIT 环境部署完成"
    echo "  🌐 SIT ArgoCD 访问地址: http://your-server-ip:30089"
    echo "  🔑 用户名: admin"
    echo "  🔑 密码: sitadmin123"
}

# Function to verify deployment
verify_deployment() {
    print_step "验证 SIT 环境部署状态..."
    
    echo ""
    echo "=== SIT 环境状态 ==="
    kubectl get applications -n argocd
    echo ""
    echo "=== SIT 环境 Pods ==="
    kubectl get pods -n microservice1-sit 2>/dev/null || echo "microservice1-sit 命名空间尚未创建"
    kubectl get pods -n microservice2-sit 2>/dev/null || echo "microservice2-sit 命名空间尚未创建"
    kubectl get pods -n monitoring-sit 2>/dev/null || echo "monitoring-sit 命名空间尚未创建"
    
    echo ""
    echo "=== SIT 环境服务访问地址 ==="
    echo "🔸 SIT ArgoCD:     http://your-server-ip:30089"
    echo "🔸 SIT Grafana:    http://your-server-ip:30085"
    echo "🔸 SIT Prometheus: http://your-server-ip:30091"
    echo "🔸 SIT AlertManager: http://your-server-ip:30094"
}

# Main deployment process
main() {
    echo "=========================================="
    echo "          SIT 环境部署脚本"
    echo "=========================================="
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    # Check ArgoCD operator
    check_argocd_operator
    
    # Deploy SIT environment
    deploy_sit_environment
    
    echo ""
    verify_deployment
    
    echo ""
    print_success "🎉 SIT 环境部署完成！"
    echo ""
    echo "📚 后续操作建议:"
    echo "  1. 登录 SIT ArgoCD 验证应用状态"
    echo "  2. 检查微服务和监控组件运行状态"
    echo "  3. 访问 Grafana 查看监控数据"
    echo "  4. 验证与 DEV 环境完全独立"
}

# Script usage
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "用法: $0"
    echo ""
    echo "这个脚本用于部署 SIT 环境的所有组件"
    echo "包括 microservice1-sit, microservice2-sit 和 monitoring-sit"
    exit 0
fi

# Run main function
main "$@"