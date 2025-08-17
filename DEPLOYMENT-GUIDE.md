# 独立环境 ArgoCD 部署验证指南

## 📋 部署前准备

### 1. 安装必要工具

#### 安装 kubectl (Windows)
```powershell
# 方法1: 使用 Chocolatey
choco install kubernetes-cli

# 方法2: 使用 Scoop
scoop install kubectl

# 方法3: 手动下载
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
```

#### 验证 kubectl 安装
```bash
kubectl version --client
```

### 2. 确保 Kubernetes 集群访问
```bash
kubectl cluster-info
kubectl get nodes
```

## 🚀 DEV 环境部署

### 步骤1: 切换到 DEV 分支
```bash
cd project-gitops-config
git checkout dev
git pull origin dev
```

### 步骤2: 清理可能存在的 ArgoCD
```bash
# 删除现有的 ArgoCD 相关资源
kubectl delete namespace argocd --ignore-not-found=true
kubectl delete applications --all -A --ignore-not-found=true

# 等待命名空间完全删除
kubectl wait --for=delete namespace/argocd --timeout=60s
```

### 步骤3: 部署 DEV 环境
```bash
# 安装 ArgoCD (如果未安装)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待 ArgoCD 就绪
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd

# 部署 DEV 应用
./deploy-dev-environment.sh
```

### 步骤4: 暴露 DEV ArgoCD 服务
```bash
# 方法1: 使用 NodePort (推荐)
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080}]}}'

# 方法2: 使用 Port Forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

### 步骤5: 获取 DEV ArgoCD 密码
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## 🧪 SIT 环境部署

### 步骤1: 切换到 SIT 分支
```bash
git checkout sit
git pull origin sit
```

### 步骤2: 部署 SIT 环境 (独立实例)
```bash
# 如果需要独立的 SIT ArgoCD 实例
kubectl create namespace argocd-sit
kubectl apply -n argocd-sit -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待 SIT ArgoCD 就绪
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd-sit

# 部署 SIT 应用
./deploy-sit-environment.sh
```

### 步骤3: 暴露 SIT ArgoCD 服务
```bash
# 使用不同的 NodePort
kubectl patch svc argocd-server -n argocd-sit -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30089}]}}'
```

### 步骤4: 获取 SIT ArgoCD 密码
```bash
kubectl -n argocd-sit get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## 🔍 部署验证

### 检查 DEV 环境状态
```bash
echo "=== DEV 环境检查 ==="
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get svc -n argocd | grep argocd-server
```

### 检查 SIT 环境状态  
```bash
echo "=== SIT 环境检查 ==="
kubectl get pods -n argocd-sit
kubectl get applications -n argocd-sit
kubectl get svc -n argocd-sit | grep argocd-server
```

### 检查微服务应用状态
```bash
echo "=== 微服务状态检查 ==="
kubectl get pods -n microservice1-dev 2>/dev/null || echo "microservice1-dev 尚未部署"
kubectl get pods -n microservice2-dev 2>/dev/null || echo "microservice2-dev 尚未部署"
kubectl get pods -n monitoring 2>/dev/null || echo "monitoring 尚未部署"

kubectl get pods -n microservice1-sit 2>/dev/null || echo "microservice1-sit 尚未部署"
kubectl get pods -n microservice2-sit 2>/dev/null || echo "microservice2-sit 尚未部署"
kubectl get pods -n monitoring-sit 2>/dev/null || echo "monitoring-sit 尚未部署"
```

## 🌐 访问地址

部署成功后，您可以通过以下地址访问：

### DEV 环境
- **ArgoCD**: http://your-cluster-ip:30080
- **Grafana**: http://your-cluster-ip:30081 (部署完成后)
- **Prometheus**: http://your-cluster-ip:30090 (部署完成后)

### SIT 环境
- **ArgoCD**: http://your-cluster-ip:30089
- **Grafana**: http://your-cluster-ip:30085 (部署完成后)
- **Prometheus**: http://your-cluster-ip:30091 (部署完成后)

### 获取集群 IP
```bash
# 获取节点 IP
kubectl get nodes -o wide

# 或者使用 Docker Desktop 的话，通常是
echo "localhost 或 127.0.0.1"
```

## 🚨 故障排除

### ArgoCD Pod 启动失败
```bash
kubectl describe pods -n argocd | grep -A 5 "Events"
kubectl logs -n argocd deployment/argocd-server
```

### 应用同步失败
```bash
kubectl describe applications -n argocd
```

### 端口访问问题
```bash
# 检查 NodePort 服务
kubectl get svc -n argocd -o wide
kubectl get svc -n argocd-sit -o wide

# 如果 NodePort 不可访问，使用 Port Forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 📝 部署完成检查清单

- [ ] kubectl 已安装并可访问集群
- [ ] DEV ArgoCD 部署成功 (namespace: argocd)
- [ ] SIT ArgoCD 部署成功 (namespace: argocd-sit)
- [ ] DEV ArgoCD 可通过 http://cluster-ip:30080 访问
- [ ] SIT ArgoCD 可通过 http://cluster-ip:30089 访问
- [ ] DEV 和 SIT 环境完全独立，无配置交叉
- [ ] 微服务应用开始同步部署
- [ ] 监控组件开始部署

## 🎯 下一步

部署完成后，您可以：
1. 登录各环境的 ArgoCD 验证应用状态
2. 检查微服务是否正常部署
3. 访问 Grafana 查看监控数据
4. 验证环境间的完全隔离