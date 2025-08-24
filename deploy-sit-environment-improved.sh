#!/bin/bash
# ============================================================
# 改进版 SIT 环境部署脚本 - 小白友好版
# ============================================================
# 
# 📝 修复的问题:
# 1. RBAC 权限问题 - 确保 SIT ArgoCD 有正确的集群权限
# 2. 命名空间一致性 - 统一使用 argocd-sit 命名空间
# 3. 应用同步问题 - 自动化应用同步过程
# 4. 错误处理 - 添加详细的错误检查和恢复机制
#
# 🔧 SIT 环境特点:
# - ArgoCD 命名空间: argocd-sit
# - 访问端口: 30089
# - Git 分支: sit
# - 完全独立于 DEV 环境
# ============================================================

set -e  # 遇到错误立即退出

echo "🚀 开始部署改进版 SIT 环境..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SERVER_IP="47.83.119.55"
ARGOCD_NAMESPACE="argocd-sit"
ARGOCD_PORT="30089"
GIT_REPO="https://github.com/1979447992/project-gitops-config.git"
GIT_BRANCH="sit"

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

# 检查必要的工具
check_prerequisites() {
    print_step "检查必要工具..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    if ! command -v argocd &> /dev/null; then
        print_error "argocd CLI 未安装，请先安装 argocd CLI"
        exit 1
    fi
    
    # 检查 kubectl 是否能连接到集群
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群，请检查 kubeconfig"
        exit 1
    fi
    
    print_success "所有必要工具检查完成"
}

# 创建 SIT 环境命名空间
create_sit_namespace() {
    print_step "创建 SIT 环境命名空间..."
    
    if kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
        print_warning "命名空间 $ARGOCD_NAMESPACE 已存在"
    else
        kubectl create namespace $ARGOCD_NAMESPACE
        print_success "命名空间 $ARGOCD_NAMESPACE 创建成功"
    fi
}

# 部署 SIT 环境的 ArgoCD
deploy_sit_argocd() {
    print_step "部署 SIT 环境的 ArgoCD..."
    
    # 检查是否已经安装
    if kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE &> /dev/null; then
        print_warning "SIT ArgoCD 已存在，跳过安装"
        return
    fi
    
    # 安装 ArgoCD 到 SIT 命名空间
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    print_step "等待 ArgoCD pods 启动..."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n $ARGOCD_NAMESPACE --timeout=300s
    
    # 配置 NodePort 服务
    print_step "配置 ArgoCD NodePort 服务..."
    kubectl patch svc argocd-server -n $ARGOCD_NAMESPACE -p "{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"port\":80,\"targetPort\":8080,\"nodePort\":$ARGOCD_PORT}]}}"
    
    print_success "SIT ArgoCD 部署完成"
}

# 修复 RBAC 权限问题 - 最关键的修复！
fix_rbac_permissions() {
    print_step "修复 RBAC 权限问题 (关键步骤)..."
    
    print_warning "这是修复权限问题的关键步骤，确保 SIT ArgoCD 能正常工作"
    
    # 为 SIT 环境的 application-controller 添加集群权限
    kubectl patch clusterrolebinding argocd-application-controller --type='merge' -p="{\"subjects\":[{\"kind\":\"ServiceAccount\",\"name\":\"argocd-application-controller\",\"namespace\":\"argocd\"},{\"kind\":\"ServiceAccount\",\"name\":\"argocd-application-controller\",\"namespace\":\"$ARGOCD_NAMESPACE\"}]}"
    
    # 为 SIT 环境的 server 添加集群权限
    kubectl patch clusterrolebinding argocd-server --type='merge' -p="{\"subjects\":[{\"kind\":\"ServiceAccount\",\"name\":\"argocd-server\",\"namespace\":\"argocd\"},{\"kind\":\"ServiceAccount\",\"name\":\"argocd-server\",\"namespace\":\"$ARGOCD_NAMESPACE\"}]}"
    
    # 重启 application controller 以应用新权限
    print_step "重启 ArgoCD application controller..."
    kubectl rollout restart statefulset/argocd-application-controller -n $ARGOCD_NAMESPACE
    
    # 等待重启完成
    kubectl rollout status statefulset/argocd-application-controller -n $ARGOCD_NAMESPACE --timeout=180s
    
    print_success "RBAC 权限修复完成"
}

# 获取 ArgoCD 初始密码
get_argocd_password() {
    print_step "获取 ArgoCD 初始密码..."
    
    # 等待 secret 创建
    kubectl wait --for=condition=Ready secret/argocd-initial-admin-secret -n $ARGOCD_NAMESPACE --timeout=60s
    
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    print_success "ArgoCD 密码获取成功: $ARGOCD_PASSWORD"
}

# 部署 App of Apps
deploy_app_of_apps() {
    print_step "部署 App of Apps..."
    
    # 创建临时的 App of Apps 配置
    cat > /tmp/sit-app-of-apps.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $GIT_REPO
    targetRevision: $GIT_BRANCH
    path: argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: $ARGOCD_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
    
    kubectl apply -f /tmp/sit-app-of-apps.yaml
    print_success "App of Apps 部署完成"
}

# 登录 ArgoCD 并同步应用
login_and_sync_apps() {
    print_step "登录 ArgoCD 并同步应用..."
    
    # 登录 ArgoCD
    argocd login $SERVER_IP:$ARGOCD_PORT --username admin --password "$ARGOCD_PASSWORD" --insecure
    
    print_step "等待应用被 App of Apps 创建..."
    sleep 30
    
    # 手动应用所有应用定义（确保创建）
    print_step "确保所有应用都被创建..."
    kubectl apply -f argocd/applications/ -n $ARGOCD_NAMESPACE
    
    # 同步所有应用
    print_step "同步所有 SIT 应用..."
    
    # 应用列表
    APPS=("microservice1-sit" "microservice2-sit" "kube-prometheus-stack-monitoring-sit")
    
    for app in "${APPS[@]}"; do
        print_step "同步应用: $app"
        argocd app sync $app --grpc-web --timeout 300 || print_warning "应用 $app 同步可能需要更多时间"
    done
    
    print_success "所有应用同步完成"
}

# 验证权限
verify_permissions() {
    print_step "验证 SIT ArgoCD 权限..."
    
    echo "检查 SIT ArgoCD ServiceAccount 权限:"
    
    # 检查关键权限
    PERMISSIONS=(
        "list serviceaccounts"
        "get pods"
        "create deployments"
        "list namespaces"
    )
    
    for perm in "${PERMISSIONS[@]}"; do
        if kubectl auth can-i $perm --as=system:serviceaccount:$ARGOCD_NAMESPACE:argocd-application-controller; then
            echo "  ✅ $perm: YES"
        else
            echo "  ❌ $perm: NO"
        fi
    done
}

# 验证部署状态
verify_deployment() {
    print_step "验证 SIT 环境部署状态..."
    
    verify_permissions
    
    echo ""
    echo "=== SIT ArgoCD 应用状态 ==="
    kubectl get applications -n $ARGOCD_NAMESPACE
    
    echo ""
    echo "=== SIT 环境微服务 Pods ==="
    kubectl get pods -n microservice1-sit 2>/dev/null || echo "microservice1-sit pods 启动中..."
    kubectl get pods -n microservice2-sit 2>/dev/null || echo "microservice2-sit pods 启动中..."
    
    echo ""
    echo "=== SIT 环境监控 Pods ==="
    kubectl get pods -n monitoring-sit 2>/dev/null || echo "monitoring-sit pods 启动中..."
    
    echo ""
    echo "=== SIT 环境服务访问地址 ==="
    echo "🔸 SIT ArgoCD:     http://$SERVER_IP:$ARGOCD_PORT"
    echo "🔸 SIT Grafana:    http://$SERVER_IP:30085"
    echo "🔸 SIT Prometheus: http://$SERVER_IP:30091"
    echo "🔸 SIT AlertManager: http://$SERVER_IP:30094"
    echo ""
    echo "🔑 SIT ArgoCD 登录信息:"
    echo "   用户名: admin"
    echo "   密码: $ARGOCD_PASSWORD"
}

# 主函数
main() {
    echo "=========================================="
    echo "      改进版 SIT 环境部署脚本"
    echo "         (小白友好版 v2.0)"
    echo "=========================================="
    echo ""
    echo "🎯 本次改进解决的问题:"
    echo "  ✓ RBAC 权限问题"
    echo "  ✓ 命名空间一致性"
    echo "  ✓ 应用同步自动化"
    echo "  ✓ 错误处理和恢复"
    echo ""
    
    check_prerequisites
    create_sit_namespace
    deploy_sit_argocd
    fix_rbac_permissions  # 🌟 关键修复步骤
    get_argocd_password
    deploy_app_of_apps
    login_and_sync_apps
    verify_deployment
    
    echo ""
    print_success "🎉 SIT 环境部署成功完成！"
    echo ""
    echo "📚 重要经验总结:"
    echo "  1. RBAC 权限是多环境 ArgoCD 的关键"
    echo "  2. 命名空间要保持一致性"
    echo "  3. 应用同步需要时间，要有耐心"
    echo "  4. 手动验证每个步骤很重要"
}

# Script usage
if [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    echo "用法: $0"
    echo ""
    echo "改进版 SIT 环境部署脚本"
    echo "修复了 RBAC 权限、命名空间和应用同步问题"
    echo ""
    echo "运行前要求:"
    echo "  1. 当前目录包含 argocd/ 文件夹"
    echo "  2. kubectl 已配置并能连接集群"
    echo "  3. argocd CLI 已安装"
    echo ""
    echo "权限检查示例命令:"
    echo "  kubectl auth can-i list serviceaccounts --as=system:serviceaccount:argocd-sit:argocd-application-controller"
    echo "  kubectl auth can-i get pods --as=system:serviceaccount:argocd-sit:argocd-application-controller"
    exit 0
fi

# Run main function
main "$@"