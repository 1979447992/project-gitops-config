#!/bin/bash
# ============================================================
# 独立环境部署脚本 - 企业级 GitOps 架构
# ============================================================
# 
# 📝 学习说明:
# 这个脚本实现了企业级的独立环境部署模式
# 每个环境都有自己的 ArgoCD 实例，完全隔离
#
# 🔧 部署架构:
# - DEV 环境: argocd 命名空间 (端口 30080)
# - SIT 环境: argocd-sit 命名空间 (端口 30089)
# - 各环境使用不同的分支配置 (dev/sit)
#
# 🌟 企业级优势:
# - 完全的环境隔离
# - 独立的故障域和权限管理
# - 分支策略清晰，易于维护
# ============================================================

set -e

echo "🚀 开始部署独立环境 GitOps 架构..."

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

# Function to deploy DEV environment
deploy_dev_environment() {
    print_step "部署 DEV 环境 ArgoCD..."
    
    # Ensure DEV ArgoCD namespace exists
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy DEV App of Apps (using existing ArgoCD)
    kubectl apply -f argocd/app-of-apps.yaml
    
    print_success "DEV 环境部署完成"
    echo "  🌐 DEV ArgoCD 访问地址: http://your-server-ip:30080"
    echo "  🔑 用户名: admin"
    echo "  🔑 密码: 使用命令获取: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Function to deploy SIT environment
deploy_sit_environment() {
    print_step "部署 SIT 环境独立 ArgoCD..."
    
    # Deploy SIT ArgoCD instance
    kubectl apply -f argocd-sit/argocd-install.yaml
    
    # Wait for SIT ArgoCD to be ready
    print_step "等待 SIT ArgoCD 就绪..."
    kubectl wait --for=condition=Available --timeout=300s deployment/argocd-sit-server -n argocd-sit
    
    # Deploy SIT App of Apps
    kubectl apply -f argocd-sit/sit-app-of-apps.yaml
    
    print_success "SIT 环境部署完成"
    echo "  🌐 SIT ArgoCD 访问地址: http://your-server-ip:30089"
    echo "  🔑 用户名: admin"
    echo "  🔑 密码: sitadmin123"
}

# Function to verify deployments
verify_deployments() {
    print_step "验证部署状态..."
    
    echo ""
    echo "=== DEV 环境状态 ==="
    kubectl get pods -n argocd
    kubectl get pods -n microservice1-dev
    kubectl get pods -n microservice2-dev
    kubectl get pods -n monitoring
    
    echo ""
    echo "=== SIT 环境状态 ==="
    kubectl get pods -n argocd-sit
    kubectl get pods -n microservice1-sit
    kubectl get pods -n microservice2-sit
    kubectl get pods -n monitoring-sit
    
    echo ""
    echo "=== 服务访问地址 ==="
    echo "🔸 DEV ArgoCD:     http://your-server-ip:30080"
    echo "🔸 DEV Grafana:    http://your-server-ip:30081"
    echo "🔸 DEV Prometheus: http://your-server-ip:30090"
    echo ""
    echo "🔸 SIT ArgoCD:     http://your-server-ip:30089"
    echo "🔸 SIT Grafana:    http://your-server-ip:30085"
    echo "🔸 SIT Prometheus: http://your-server-ip:30091"
}

# Main deployment process
main() {
    echo "=========================================="
    echo "    企业级独立环境 GitOps 部署脚本"
    echo "=========================================="
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    # Check ArgoCD operator
    check_argocd_operator
    
    # Deploy environments
    case "${1:-both}" in
        "dev")
            deploy_dev_environment
            ;;
        "sit")
            deploy_sit_environment
            ;;
        "both"|*)
            deploy_dev_environment
            echo ""
            deploy_sit_environment
            ;;
    esac
    
    echo ""
    verify_deployments
    
    echo ""
    print_success "🎉 独立环境部署完成！"
    echo ""
    echo "📚 后续操作建议:"
    echo "  1. 分别登录 DEV 和 SIT ArgoCD 验证应用状态"
    echo "  2. 检查各环境的微服务和监控组件运行状态"
    echo "  3. 验证环境间完全隔离，互不影响"
    echo "  4. 配置适当的 RBAC 权限控制"
}

# Script usage
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "用法: $0 [dev|sit|both]"
    echo ""
    echo "选项:"
    echo "  dev   - 只部署 DEV 环境"
    echo "  sit   - 只部署 SIT 环境"
    echo "  both  - 部署两个环境 (默认)"
    echo "  -h    - 显示此帮助信息"
    exit 0
fi

# Run main function
main "$@"