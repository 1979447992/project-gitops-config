# 独立环境 GitOps 架构文档

## 🏗️ 架构概述

本项目已重构为企业级独立环境部署模式，每个环境都有独立的 ArgoCD 实例，完全符合企业级 GitOps 最佳实践。

### 架构特点
- **完全环境隔离**: DEV 和 SIT 环境使用独立的 ArgoCD 实例
- **分支策略清晰**: DEV 使用 `dev` 分支，SIT 使用 `sit` 分支
- **独立故障域**: 一个环境的问题不会影响另一个环境
- **权限分离**: 不同环境可以有不同的权限管理

## 🌐 环境配置

### DEV 环境
- **ArgoCD 命名空间**: `argocd`
- **ArgoCD 访问端口**: `30080`
- **Git 分支**: `dev`
- **应用命名空间**:
  - microservice1-dev
  - microservice2-dev
  - monitoring
- **服务端口**:
  - Grafana: `30081`
  - Prometheus: `30090`
  - AlertManager: `30093`

### SIT 环境
- **ArgoCD 命名空间**: `argocd-sit`
- **ArgoCD 访问端口**: `30089`
- **Git 分支**: `sit`
- **应用命名空间**:
  - microservice1-sit
  - microservice2-sit
  - monitoring-sit
- **服务端口**:
  - Grafana: `30085`
  - Prometheus: `30091`
  - AlertManager: `30094`

## 📁 目录结构

```
project-gitops-config/
├── argocd/                           # DEV 环境 ArgoCD 配置
│   ├── app-of-apps.yaml             # DEV App of Apps (指向 dev 分支)
│   ├── dev-app-of-apps.yaml         # 备用 DEV App of Apps 配置
│   └── applications/                # DEV 环境应用定义
│       ├── microservice1-dev.yaml
│       ├── microservice2-dev.yaml
│       └── kube-prometheus-stack-monitoring-dev.yaml
├── argocd-sit/                      # SIT 环境 ArgoCD 配置
│   ├── argocd-install.yaml          # SIT ArgoCD 实例定义
│   ├── sit-app-of-apps.yaml         # SIT App of Apps (指向 sit 分支)
│   └── applications/                # SIT 环境应用定义
│       ├── microservice1-sit.yaml
│       ├── microservice2-sit.yaml
│       └── kube-prometheus-stack-monitoring-sit.yaml
├── charts/                          # Helm charts
├── environments/                    # 环境特定配置
│   ├── dev/                        # DEV 环境 values
│   └── sit/                        # SIT 环境 values
└── deploy-independent-environments.sh # 部署脚本
```

## 🚀 部署指南

### 前置条件
1. Kubernetes 集群已就绪
2. kubectl 已配置并可访问集群
3. ArgoCD Operator 已安装（脚本会自动检查和安装）

### 快速部署
```bash
# 部署两个环境（推荐）
./deploy-independent-environments.sh

# 只部署 DEV 环境
./deploy-independent-environments.sh dev

# 只部署 SIT 环境
./deploy-independent-environments.sh sit
```

### 手动部署

#### 部署 DEV 环境
```bash
# 应用 DEV App of Apps
kubectl apply -f argocd/app-of-apps.yaml
```

#### 部署 SIT 环境
```bash
# 部署 SIT ArgoCD 实例
kubectl apply -f argocd-sit/argocd-install.yaml

# 等待 ArgoCD 就绪后应用 SIT App of Apps
kubectl apply -f argocd-sit/sit-app-of-apps.yaml
```

## 🔐 访问信息

### DEV 环境访问
- **ArgoCD**: http://your-server-ip:30080
  - 用户名: admin
  - 密码: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- **Grafana**: http://your-server-ip:30081
  - 用户名: admin
  - 密码: devadmin123

### SIT 环境访问
- **ArgoCD**: http://your-server-ip:30089
  - 用户名: admin
  - 密码: sitadmin123
- **Grafana**: http://your-server-ip:30085
  - 用户名: admin
  - 密码: sitadmin123

## 🔄 GitOps 工作流

### 开发流程
1. **功能开发**: 在 feature 分支开发
2. **DEV 测试**: 合并到 `dev` 分支，自动部署到 DEV 环境
3. **SIT 测试**: 合并到 `sit` 分支，自动部署到 SIT 环境
4. **生产发布**: 合并到 `main` 分支（用于生产环境）

### 配置更新
- **DEV 配置更新**: 修改 `environments/dev/` 下的文件
- **SIT 配置更新**: 修改 `environments/sit/` 下的文件
- **应用定义更新**: 修改对应环境的 `applications/` 目录

## 🛠️ 维护操作

### 查看环境状态
```bash
# DEV 环境
kubectl get applications -n argocd
kubectl get pods -n microservice1-dev
kubectl get pods -n microservice2-dev
kubectl get pods -n monitoring

# SIT 环境
kubectl get applications -n argocd-sit
kubectl get pods -n microservice1-sit
kubectl get pods -n microservice2-sit
kubectl get pods -n monitoring-sit
```

### 强制同步应用
```bash
# DEV 环境
argocd app sync microservice1-dev --grpc-web --server your-server-ip:30080
argocd app sync microservice2-dev --grpc-web --server your-server-ip:30080

# SIT 环境
argocd app sync microservice1-sit --grpc-web --server your-server-ip:30089
argocd app sync microservice2-sit --grpc-web --server your-server-ip:30089
```

### 删除环境
```bash
# 删除 DEV 环境（保留 ArgoCD）
kubectl delete applications --all -n argocd
kubectl delete namespace microservice1-dev microservice2-dev monitoring

# 删除 SIT 环境（包括 ArgoCD）
kubectl delete namespace argocd-sit microservice1-sit microservice2-sit monitoring-sit
```

## 🎯 企业级最佳实践

### 1. 环境隔离
- ✅ 独立的 ArgoCD 实例
- ✅ 独立的命名空间
- ✅ 独立的配置分支
- ✅ 独立的访问端口

### 2. 安全考虑
- 🔐 不同环境使用不同的管理员密码
- 🔐 RBAC 权限分离
- 🔐 网络策略隔离（可选）

### 3. 监控和可观测性
- 📊 每个环境独立的 Prometheus/Grafana
- 📊 环境特定的告警规则
- 📊 独立的数据保留策略

### 4. 配置管理
- 📝 环境特定的 Helm values
- 📝 分支策略清晰
- 📝 配置版本化管理

## 🚨 故障排除

### 常见问题

1. **ArgoCD 无法访问**
   - 检查服务状态: `kubectl get svc -n argocd-sit`
   - 确认端口映射正确
   - 检查防火墙设置

2. **应用同步失败**
   - 检查 Git 仓库访问权限
   - 验证分支名称正确
   - 查看 ArgoCD 日志

3. **资源冲突**
   - 确认不同环境使用不同的命名空间
   - 检查 NodePort 端口是否冲突
   - 验证资源名称唯一性

## 📚 相关资源

- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [GitOps 最佳实践](https://www.gitops.tech/)
- [Kubernetes 多环境管理](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)