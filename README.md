# Project GitOps Configuration

本仓库包含项目的Kubernetes部署配置，使用ArgoCD进行GitOps部署。

## 仓库结构

```
project-gitops-config/
├── argocd/
│   ├── app-of-apps.yaml
│   └── applications/
├── charts/
│   ├── microservice1/
│   └── microservice2/
├── environments/
│   ├── dev/
│   └── staging/
└── README.md
```

## 部署流程

1. 开发者推送代码到微服务仓库
2. CI流水线构建Docker镜像并推送到镜像仓库
3. CI流水线自动更新本仓库中对应环境的values文件
4. ArgoCD检测到配置变更，自动同步到Kubernetes集群

## ArgoCD应用管理

### 安装App of Apps
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

## 环境说明

- **dev**: 开发环境
- **staging**: 预发布环境
