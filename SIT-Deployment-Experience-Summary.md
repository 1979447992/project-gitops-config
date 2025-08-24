# SIT 环境部署经验总结 - 小白必读指南

> 本文档总结了 SIT 环境部署过程中遇到的问题、解决方案和重要经验，适合 Kubernetes 和 ArgoCD 初学者阅读。

## 🎯 部署成果

### 最终成功部署的环境
- **DEV ArgoCD**: `argocd` 命名空间 (端口 30080)
- **SIT ArgoCD**: `argocd-sit` 命名空间 (端口 30089) 
- **完全环境隔离**: 两个独立的 ArgoCD 实例管理各自环境

### 访问地址
- SIT ArgoCD: http://47.83.119.55:30089
- SIT Grafana: http://47.83.119.55:30085  
- SIT Prometheus: http://47.83.119.55:30091
- SIT AlertManager: http://47.83.119.55:30094

## 🚨 遇到的主要问题及解决方案

### 问题 1: RBAC 权限错误 ⭐ **最关键问题**

#### 问题现象
```
serviceaccounts is forbidden: User "system:serviceaccount:argocd-sit:argocd-application-controller" 
cannot list resource "serviceaccounts" at the cluster scope
```

#### 小白解释 🎓
想象 Kubernetes 集群像一个大公司：
- **ArgoCD** 就像是项目经理，需要管理各种资源
- **RBAC** 就像是公司的权限系统，决定谁能做什么
- **ClusterRoleBinding** 就像是全公司通用的权限证书

我们的问题：
1. DEV 环境的 ArgoCD（argocd 命名空间）有权限证书
2. SIT 环境的 ArgoCD（argocd-sit 命名空间）没有权限证书
3. 所以 SIT ArgoCD 被"保安"拦在门外，看不到集群资源

#### 解决方案
```bash
# 给 SIT 环境的 application-controller 添加权限
kubectl patch clusterrolebinding argocd-application-controller --type='merge' \
-p='{"subjects":[
  {"kind":"ServiceAccount","name":"argocd-application-controller","namespace":"argocd"},
  {"kind":"ServiceAccount","name":"argocd-application-controller","namespace":"argocd-sit"}
]}'

# 给 SIT 环境的 server 添加权限
kubectl patch clusterrolebinding argocd-server --type='merge' \
-p='{"subjects":[
  {"kind":"ServiceAccount","name":"argocd-server","namespace":"argocd"},
  {"kind":"ServiceAccount","name":"argocd-server","namespace":"argocd-sit"}
]}'

# 重启以应用新权限
kubectl rollout restart statefulset/argocd-application-controller -n argocd-sit
```

#### 权限验证命令
```bash
# 检查 SIT 环境 ArgoCD 权限的正确命令格式
kubectl auth can-i list serviceaccounts --as=system:serviceaccount:argocd-sit:argocd-application-controller
kubectl auth can-i get pods --as=system:serviceaccount:argocd-sit:argocd-application-controller
kubectl auth can-i create deployments --as=system:serviceaccount:argocd-sit:argocd-application-controller
```

### 问题 2: 命名空间不一致

#### 问题现象
- App of Apps 部署在 `argocd` 命名空间
- 应用配置指向 `argocd-sit` 命名空间
- 子应用无法被创建

#### 小白解释 🎓
这就像：
- 你在 2 楼开了一个"应用工厂"（App of Apps）
- 但是工厂的配置说"把产品送到 3 楼"
- 结果产品找不到正确的楼层

#### 解决方案
- 在 `argocd-sit` 命名空间部署独立的 ArgoCD 实例
- 确保 App of Apps 和子应用都在同一命名空间

### 问题 3: 应用同步延迟

#### 问题现象
- App of Apps 创建成功
- 子应用长时间不出现
- 应用状态显示 "Unknown"

#### 小白解释 🎓
App of Apps 就像一个慢性子的工厂经理：
- 他知道要生产什么
- 但是需要时间来安排生产线
- 有时需要人工催促一下

#### 解决方案
```bash
# 等待一段时间
sleep 30

# 手动确保应用被创建
kubectl apply -f argocd/applications/ -n argocd-sit

# 手动同步应用
argocd app sync microservice1-sit --grpc-web
argocd app sync microservice2-sit --grpc-web
argocd app sync kube-prometheus-stack-monitoring-sit --grpc-web
```

## 📚 重要经验总结

### 1. 多环境 ArgoCD 部署要点

#### ✅ 正确做法
- 每个环境使用独立的命名空间
- 为每个环境的 ServiceAccount 分配 RBAC 权限
- 使用不同的 NodePort 端口避免冲突
- 确保 Git 分支策略与环境一致

#### ❌ 常见错误
- 试图在同一命名空间部署多个 ArgoCD
- 忘记为新环境配置 RBAC 权限
- 命名空间配置不一致
- 没有验证权限是否生效

### 2. RBAC 权限管理

#### 关键概念 🎓
```
ServiceAccount (服务账户)
    ↓ 绑定到
ClusterRoleBinding (集群角色绑定)
    ↓ 引用
ClusterRole (集群角色)
    ↓ 定义
Permissions (具体权限)
```

#### 实际应用
- ArgoCD 需要集群级权限来管理所有命名空间的资源
- 每个 ArgoCD 实例的 ServiceAccount 都需要单独配置
- 权限修改后需要重启相关组件才能生效

### 3. 关于两个 ArgoCD 实例

#### 这是正确的企业级实践！
```
DEV 环境 (argocd 命名空间)
├── ArgoCD UI: http://47.83.119.55:30080
├── Git 分支: dev
└── 管理: DEV 应用

SIT 环境 (argocd-sit 命名空间)  
├── ArgoCD UI: http://47.83.119.55:30089
├── Git 分支: sit
└── 管理: SIT 应用
```

#### 优点
- **完全隔离**: 环境互不影响
- **独立管理**: 不同的权限和配置
- **故障隔离**: 一个环境出问题不影响另一个
- **符合企业实践**: 生产环境常用的部署模式

## 🛠️ 改进版脚本特性

### 新增功能
1. **自动权限修复**: 脚本自动配置 RBAC 权限
2. **环境检查**: 检查是否已存在 ArgoCD 实例
3. **权限验证**: 部署后验证权限是否正确
4. **错误处理**: 每步都有详细的错误检查
5. **自动同步**: 自动登录并同步所有应用

### 使用方法
```bash
# 在项目根目录运行
./deploy-sit-environment-improved.sh

# 查看帮助和权限检查示例
./deploy-sit-environment-improved.sh --help
```

## 🎓 小白调试技巧

### 常用权限检查命令
```bash
# 检查 SIT 环境 ArgoCD 的各种权限
kubectl auth can-i list serviceaccounts --as=system:serviceaccount:argocd-sit:argocd-application-controller
kubectl auth can-i get pods --as=system:serviceaccount:argocd-sit:argocd-application-controller  
kubectl auth can-i create deployments --as=system:serviceaccount:argocd-sit:argocd-application-controller
kubectl auth can-i list namespaces --as=system:serviceaccount:argocd-sit:argocd-application-controller
kubectl auth can-i "*" applications.argoproj.io --as=system:serviceaccount:argocd-sit:argocd-application-controller
```

### 问题排查流程
1. **检查基础环境**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

2. **检查 ArgoCD 状态**
   ```bash
   kubectl get pods -n argocd-sit
   kubectl logs -n argocd-sit deployment/argocd-server
   ```

3. **检查权限配置**
   ```bash
   kubectl get clusterrolebinding argocd-application-controller -o yaml
   kubectl get clusterrolebinding argocd-server -o yaml
   ```

4. **检查应用状态**
   ```bash
   kubectl get applications -n argocd-sit
   kubectl describe application microservice1-sit -n argocd-sit
   ```

### ArgoCD 常用命令
```bash
# 连接到 SIT ArgoCD
argocd login 47.83.119.55:30089 --username admin --password <password> --insecure

# 查看应用列表
argocd app list

# 查看应用详情
argocd app get microservice1-sit

# 手动同步应用
argocd app sync microservice1-sit --grpc-web

# 查看应用历史
argocd app history microservice1-sit
```

## 🔮 学习建议

### 推荐学习路径
1. **Kubernetes 基础**
   - Pod、Service、Deployment 概念
   - Namespace 和 RBAC 权限管理
   - kubectl 基本命令

2. **ArgoCD 概念**
   - GitOps 工作流程
   - Application 和 App of Apps 模式
   - 同步策略和健康检查

3. **实践项目**
   - 从单环境开始练习
   - 逐步扩展到多环境
   - 学习问题排查和日志分析

### 关键理解点
- **RBAC 是多环境的关键**: 每个环境都需要独立的权限配置
- **命令格式很重要**: `kubectl auth can-i <动作> <资源> --as=<用户>`
- **耐心很重要**: 应用同步需要时间，不要急躁
- **验证很重要**: 每一步都要验证是否成功

---

💡 **记住**: 权限问题是多环境 ArgoCD 部署的最大难点，但一旦理解了 RBAC 的工作原理，就能轻松解决类似问题！