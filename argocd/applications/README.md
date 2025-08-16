# ArgoCD Applications 配置目录

这个目录包含了所有 ArgoCD Application 的定义文件，用于管理微服务和监控组件的部署。

## 📁 文件结构

### 🚀 微服务应用
- `microservice1-dev.yaml` - 微服务1 DEV环境
- `microservice1-sit.yaml` - 微服务1 SIT环境  
- `microservice2-dev.yaml` - 微服务2 DEV环境
- `microservice2-sit.yaml` - 微服务2 SIT环境

### 📊 监控组件
- `kube-prometheus-stack-monitoring.yaml` - **DEV监控环境** (当前启用)
- `kube-prometheus-stack-monitoring-sit.yaml.disabled` - **SIT监控环境** (已禁用)

## 🔧 如何管理环境

### 启用 SIT 监控环境
```bash
# 1. 重命名文件以激活
mv kube-prometheus-stack-monitoring-sit.yaml.disabled kube-prometheus-stack-monitoring-sit.yaml

# 2. 提交变更
git add .
git commit -m "Enable SIT monitoring environment"
git push

# 3. ArgoCD 会自动检测并部署
```

### 禁用 SIT 监控环境  
```bash
# 1. 重命名文件以禁用
mv kube-prometheus-stack-monitoring-sit.yaml kube-prometheus-stack-monitoring-sit.yaml.disabled

# 2. 提交变更 
git add .
git commit -m "Disable SIT monitoring environment"
git push

# 3. ArgoCD 会自动清理资源
```

## 📋 配置说明

### DEV vs SIT 环境差异

| 配置项 | DEV 环境 | SIT 环境 |
|--------|----------|----------|
| Prometheus 保留时间 | 3天 | 5天 |
| Prometheus 存储大小 | 3Gi | 5Gi |
| Grafana NodePort | 30080 | 30081 |
| 内存限制 | 1Gi | 768Mi |
| CPU限制 | 500m | 400m |

### 命名空间映射

| 应用类型 | DEV 命名空间 | SIT 命名空间 |
|----------|--------------|--------------|
| 微服务1 | `microservice1-dev` | `microservice1-sit` |
| 微服务2 | `microservice2-dev` | `microservice2-sit` |
| 监控组件 | `monitoring` | `monitoring-sit` |

## 🎯 App-of-Apps 模式

此目录使用 ArgoCD 的 **App-of-Apps** 模式:

1. `app-of-apps.yaml` 管理这个目录下的所有应用
2. 只有 `.yaml` 扩展名的文件会被自动检测
3. `.disabled` 文件会被忽略，实现配置的启用/禁用

## 📚 学习资源

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Charts](../charts/)
- [Environment Values](../environments/)