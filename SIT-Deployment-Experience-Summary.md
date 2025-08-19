# SIT 环境部署经验总结 - 小白必读

## 🚨 最关键的问题：RBAC 权限

### 问题现象
SIT 环境的 ArgoCD 无法访问 Kubernetes API，报错：
`serviceaccounts is forbidden: User "system:serviceaccount:argocd-sit:argocd-application-controller" cannot list resource "serviceaccounts"`

### 小白解释 🎓
- Kubernetes 集群 = 大公司
- ArgoCD = 项目经理，需要管理各种资源  
- RBAC = 公司权限系统
- 问题：DEV 环境的 ArgoCD 有工作证，SIT 环境的没有

### 解决方案
```bash
# 给 SIT 环境也发工作证
kubectl patch clusterrolebinding argocd-application-controller --type='merge' -p='{"subjects":[{"kind":"ServiceAccount","name":"argocd-application-controller","namespace":"argocd"},{"kind":"ServiceAccount","name":"argocd-application-controller","namespace":"argocd-sit"}]}'

# 重启让权限生效
kubectl rollout restart statefulset/argocd-application-controller -n argocd-sit
```

### 权限验证命令（正确用法）
```bash
# 检查 SIT 环境权限
kubectl auth can-i list serviceaccounts --as=system:serviceaccount:argocd-sit:argocd-application-controller
kubectl auth can-i get pods --as=system:serviceaccount:argocd-sit:argocd-application-controller
```

## 🎯 两个 ArgoCD 实例是正确的！

### 当前部署架构
- **DEV ArgoCD**: argocd 命名空间 (端口 30080)
- **SIT ArgoCD**: argocd-sit 命名空间 (端口 30089)

### 这是企业级最佳实践
✅ 完全环境隔离  
✅ 独立权限管理  
✅ 故障隔离  
✅ 符合生产标准

## 💡 核心经验
1. **RBAC 权限是多环境部署的关键**
2. **每个 ArgoCD 实例都需要独立的权限配置**
3. **权限修改后必须重启组件才生效**
4. **验证权限的命令格式很重要**

## 🚀 访问地址
- SIT ArgoCD: http://47.83.119.55:30089
- SIT Grafana: http://47.83.119.55:30085  
- SIT Prometheus: http://47.83.119.55:30091
- SIT AlertManager: http://47.83.119.55:30094

记住：权限问题解决后，一切就都正常了！🎉
