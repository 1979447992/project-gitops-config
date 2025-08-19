#!/bin/bash
# 改进版 SIT 环境部署脚本 - 修复 RBAC 权限问题
# 解决了最关键的权限问题，确保多环境 ArgoCD 正常工作

echo "🚀 开始修复 SIT 环境权限问题..."

# 修复 RBAC 权限 - 关键步骤
echo "📋 修复 RBAC 权限..."
kubectl patch clusterrolebinding argocd-application-controller --type="merge" -p="{\"subjects\":[{\"kind\":\"ServiceAccount\",\"name\":\"argocd-application-controller\",\"namespace\":\"argocd\"},{\"kind\":\"ServiceAccount\",\"name\":\"argocd-application-controller\",\"namespace\":\"argocd-sit\"}]}"

kubectl patch clusterrolebinding argocd-server --type="merge" -p="{\"subjects\":[{\"kind\":\"ServiceAccount\",\"name\":\"argocd-server\",\"namespace\":\"argocd\"},{\"kind\":\"ServiceAccount\",\"name\":\"argocd-server\",\"namespace\":\"argocd-sit\"}]}"

# 重启以应用权限
kubectl rollout restart statefulset/argocd-application-controller -n argocd-sit

echo "✅ RBAC 权限修复完成！"
echo "🎯 现在可以验证权限："
echo "kubectl auth can-i list serviceaccounts --as=system:serviceaccount:argocd-sit:argocd-application-controller"
