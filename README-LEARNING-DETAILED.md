# 📚 GitOps 配置详细学习文档

这是基于 ArgoCD 的 GitOps 配置仓库，实现了微服务的声明式部署和环境管理。

## 📁 项目结构全解析

```
project-gitops-config/
├── README.md                      # 项目说明文档
├── argocd/                        # ArgoCD 配置目录
│   ├── app-of-apps.yaml          # App-of-Apps 模式主配置
│   └── applications/              # 各应用的 ArgoCD Application 定义
│       ├── README.md              # 应用配置说明
│       ├── microservice1-dev.yaml    # 微服务1 DEV环境应用定义
│       ├── microservice1-sit.yaml    # 微服务1 SIT环境应用定义
│       ├── microservice2-dev.yaml    # 微服务2 DEV环境应用定义
│       ├── microservice2-sit.yaml    # 微服务2 SIT环境应用定义
│       ├── kube-prometheus-stack-monitoring.yaml          # DEV监控应用定义
│       └── kube-prometheus-stack-monitoring-sit.yaml.disabled  # SIT监控应用(已禁用)
├── charts/                        # Helm Chart 模板目录
│   ├── microservice1/            # 微服务1 Helm Chart
│   ├── microservice2/            # 微服务2 Helm Chart  
│   └── kube-prometheus-stack/    # 监控栈 Helm Chart
└── environments/                  # 环境特定配置
    ├── dev/                      # DEV环境配置
    ├── sit/                      # SIT环境配置
    └── staging/                  # STAGING环境配置
```

---

## 🚀 ArgoCD App-of-Apps 模式详解

### app-of-apps.yaml 逐行解析

**📝 这是 ArgoCD 的 App-of-Apps 模式实现，用于管理多个应用的部署**

```yaml
apiVersion: argoproj.io/v1alpha1
# 🌟 API版本: ArgoCD Application的API版本标识
# 固定写法: ArgoCD v1alpha1 API规范

kind: Application  
# 🌟 资源类型: ArgoCD Application资源
# 固定写法: ArgoCD的核心资源类型

metadata:
  name: project-app-of-apps
  # 🔧 应用名称: 管理所有子应用的根应用名称
  # 💡 命名约定: 通常使用项目名-app-of-apps格式
  
  namespace: argocd
  # 🌟 命名空间: ArgoCD Application必须部署在argocd命名空间
  # 固定写法: ArgoCD的标准部署命名空间

spec:
  project: default
  # 🔧 ArgoCD项目: 指定应用所属的ArgoCD项目
  # 💡 权限管理: 可通过项目控制应用的权限和策略
  
  source:
    repoURL: https://github.com/1979447992/project-gitops-config.git
    # 🌟 Git仓库: GitOps配置的源仓库地址
    # 🔧 可配置: 根据实际Git仓库地址修改
    
    targetRevision: main
    # 🌟 目标分支: 使用main分支作为配置源
    # 💡 分支策略: 生产环境建议使用标签或稳定分支
    
    path: argocd/applications
    # 🌟 配置路径: 指向applications目录，包含所有子应用定义
    # 💡 目录约定: 此目录下的所有.yaml文件都会被识别为子应用
    
  destination:
    server: https://kubernetes.default.svc
    # 🌟 目标集群: 部署到当前ArgoCD所在的Kubernetes集群
    # 固定写法: 本地集群的标准地址
    
    namespace: argocd
    # 🌟 目标命名空间: App-of-Apps本身部署在argocd命名空间
    
  syncPolicy:
    automated:
      prune: true
      # 🌟 自动清理: 删除不再需要的资源
      # 💡 安全特性: 确保集群状态与Git配置保持一致
      
      selfHeal: true
      # 🌟 自我修复: 自动修复被手动修改的资源
      # 💡 GitOps原则: 确保Git是唯一的真实来源
      
    syncOptions:
      - CreateNamespace=true
      # 🌟 命名空间创建: 自动创建不存在的命名空间
      # 💡 便利特性: 简化多环境部署的配置
```

---

## 📦 Helm Chart 模板详解

### microservice1/Chart.yaml 解析

**📝 Helm Chart 的元数据定义文件**

```yaml
apiVersion: v2
# 🌟 Helm API版本: 使用Helm 3.x的v2 API
# 固定写法: Helm 3的标准API版本

name: microservice1
# 🌟 Chart名称: 必须与目录名保持一致
# 💡 命名约定: 使用小写字母和连字符

description: A Helm chart for Microservice 1
# 🔧 Chart描述: 简要说明此Chart的用途

type: application
# 🌟 Chart类型: application表示这是应用程序Chart
# 💡 类型选择: 与library类型区分，application用于部署

version: 0.1.0
# 🌟 Chart版本: 语义化版本号，每次Chart变更时递增
# 💡 版本管理: 与应用版本独立管理

appVersion: "1.16.0"
# 🔧 应用版本: 此Chart部署的应用版本
# 💡 版本追踪: 用于记录Chart对应的应用版本
```

### microservice1/templates/deployment.yaml 详解

**📝 Kubernetes Deployment 模板，定义了微服务的部署配置**

```yaml
apiVersion: apps/v1
# 固定写法: Kubernetes Deployment的API版本

kind: Deployment
# 固定写法: Kubernetes Deployment资源类型

metadata:
  name: {{ .Chart.Name }}
  # 🌟 Helm模板: 使用Chart名称作为Deployment名称
  # 💡 动态命名: 确保资源名称与Chart名称一致
  
  labels:
    app: {{ .Chart.Name }}
    # 🌟 标签标识: 使用app标签标识应用
    # 💡 资源关联: Service、ServiceMonitor通过此标签选择Pod

spec:
  replicas: {{ .Values.replicaCount }}
  # 🌟 副本数量: 从values.yaml读取副本配置
  # 💡 可配置性: 不同环境可设置不同的副本数

  selector:
    matchLabels:
      app: {{ .Chart.Name }}
      # 🌟 选择器: Deployment管理具有此标签的Pod
      # 固定写法: 必须与template.metadata.labels匹配

  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
        # 🌟 Pod标签: 为Pod添加应用标识标签
        # 💡 一致性: 与selector.matchLabels保持一致

    spec:
      imagePullSecrets:
        - name: ghcr-secret
        # 🌟 镜像拉取密钥: 用于从私有镜像仓库拉取镜像
        # 🔧 配置要求: 需要预先创建ghcr-secret Secret

      containers:
        - name: {{ .Chart.Name }}
          # 🌟 容器名称: 使用Chart名称作为容器名

          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          # 🌟 镜像配置: 动态拼接镜像地址和标签
          # 💡 环境隔离: 不同环境可使用不同镜像标签

          imagePullPolicy: {{ .Values.image.pullPolicy }}
          # 🌟 拉取策略: 控制何时拉取镜像
          # 💡 策略选择: Always(总是), IfNotPresent(如不存在), Never(从不)

          ports:
            - containerPort: {{ .Values.service.port }}
              # 🌟 容器端口: 容器内应用监听的端口
              # 💡 配置一致: 必须与应用的server.port保持一致

          resources:
            {{- toYaml .Values.resources | nindent 12 }}
            # 🌟 资源限制: CPU和内存的requests/limits配置
            # 💡 Helm函数: toYaml转换YAML，nindent控制缩进

          {{- if .Values.env }}
          env:
            {{- range .Values.env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          {{- end }}
          # 🌟 环境变量: 动态配置环境变量
          # 💡 条件渲染: 只有在定义了env时才渲染此部分
          # 🔧 安全处理: quote函数确保值被正确引用
```

### microservice1/templates/servicemonitor.yaml 详解

**📝 Prometheus ServiceMonitor 模板，定义了监控数据收集配置**

```yaml
apiVersion: monitoring.coreos.com/v1
# 🌟 API版本: Prometheus Operator的ServiceMonitor API
# 固定写法: 由Prometheus Operator提供的CRD

kind: ServiceMonitor
# 🌟 资源类型: ServiceMonitor是Prometheus Operator的自定义资源

metadata:
  name: microservice1-monitor
  # 🌟 监控器名称: 明确标识此监控配置

  namespace: {{ .Values.namespace | default "microservice1-dev" }}
  # 🌟 命名空间: ServiceMonitor必须与目标Service在同一命名空间
  # 💡 默认值: 如果未配置则使用微服务1的DEV命名空间

  labels:
    app: microservice1
    # 🌟 应用标签: 标识监控的应用

    release: kube-prometheus-stack
    # 🌟 Release标签: Prometheus Operator通过此标签发现ServiceMonitor
    # ⚠️ 关键配置: 必须与kube-prometheus-stack的配置匹配

    environment: {{ .Values.environment | default "dev" }}
    # 🔧 环境标签: 区分不同环境的监控配置

spec:
  selector:
    matchLabels:
      app: microservice1
      # 🌟 服务选择器: 选择要监控的Service
      # 💡 标签匹配: 与Service的标签保持一致

  endpoints:
  - port: http
    # 🌟 监控端口: 使用Service中定义的http端口

    path: /actuator/prometheus
    # 🌟 指标路径: Spring Boot Actuator暴露Prometheus指标的路径
    # 固定写法: Spring Boot Actuator的标准指标端点

    interval: 30s
    # 🌟 抓取间隔: 每30秒收集一次指标
    # 💡 频率权衡: 平衡监控精度和系统负载

    scrapeTimeout: 10s
    # 🌟 抓取超时: 10秒内必须完成指标收集
    # 💡 超时设置: 应小于interval值

  namespaceSelector:
    matchNames:
    - {{ .Values.namespace | default "microservice1-dev" }}
    # 🌟 命名空间选择: 限制监控范围到特定命名空间
    # 💡 安全隔离: 防止跨命名空间的意外监控
```

---

## 📊 监控栈配置深度解析

### charts/kube-prometheus-stack/values.yaml (当前配置)

**📝 监控栈的默认配置，已修复StorageClass问题**

```yaml
kube-prometheus-stack:
  # 🌟 Prometheus配置
  prometheus:
    prometheusSpec:
      retention: 7d
      # 🔧 数据保留: 默认保留7天数据
      
      retentionSize: "2GB"
      # 🔧 存储大小: 数据达到2GB时开始清理
      
      resources:
        limits:
          cpu: 500m
          memory: 1Gi
        requests:
          cpu: 200m
          memory: 512Mi
      # 🌟 资源配置: CPU和内存的基础配置
      
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: "local-path"
            # 🌟 存储类: 已修复，统一使用local-path
            # ⚠️ 重要: 这是解决PVC冲突的关键配置
            
            accessModes: ["ReadWriteOnce"]
            # 固定写法: 标准的访问模式
            
            resources:
              requests:
                storage: 5Gi
                # 🔧 存储容量: Prometheus数据存储大小

  # 🌟 Grafana配置  
  grafana:
    enabled: true
    adminPassword: "admin123"
    # 🔧 管理员密码: 可在环境配置中覆盖
    
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
    # 🌟 资源配置: Grafana的基础资源配置
    
    persistence:
      enabled: true
      size: 2Gi
      storageClassName: "local-path"
      # 🌟 存储配置: 已修复，使用local-path
      # ⚠️ 关键修复: 之前使用"default"导致冲突
    
    service:
      type: NodePort
      nodePort: 30080
      # 🌟 外部访问: 通过NodePort暴露Grafana

  # 🌟 AlertManager配置
  alertmanager:
    alertmanagerSpec:
      retention: 24h
      # 🔧 告警保留: 告警数据保留24小时
      
      resources:
        limits:
          cpu: 100m
          memory: 128Mi
        requests:
          cpu: 50m
          memory: 64Mi
      # 🌟 资源配置: AlertManager的资源限制
      
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: "local-path"
            # 🌟 存储类: 已修复，统一使用local-path
            
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 2Gi
                # 🔧 存储容量: AlertManager数据存储
```

### environments/dev/kube-prometheus-stack-values.yaml (DEV环境配置)

**📝 DEV环境的监控配置，包含NodePort端口配置**

```yaml
kube-prometheus-stack:
  prometheus:
    service:
      type: NodePort
      nodePort: 30090
      # 🌟 外部访问: DEV环境Prometheus端口
    
    prometheusSpec:
      retention: 3d
      # 🔧 开发环境: 较短的数据保留期
      
      retentionSize: "1GB"
      # 🔧 存储优化: 开发环境使用较小存储
      
      resources:
        limits:
          cpu: 500m
          memory: 1Gi
          # 🌟 资源配置: 开发环境适中的资源配置
        requests:
          cpu: 200m
          memory: 512Mi
      
      # 🌟 监控发现: 开发环境监控所有命名空间
      serviceMonitorNamespaceSelector: {}
      ruleNamespaceSelector: {}

  grafana:
    adminPassword: "devadmin123"
    # 🔧 开发密码: DEV环境特定密码
    
    service:
      type: NodePort
      nodePort: 30080
      # 🌟 外部访问: DEV环境Grafana端口
    
    # 🌟 匿名访问: 开发环境允许匿名查看
    grafana.ini:
      auth.anonymous:
        enabled: true
        org_role: Viewer

  alertmanager:
    service:
      type: NodePort
      nodePort: 30093
      # 🌟 外部访问: DEV环境AlertManager端口
    
    alertmanagerSpec:
      retention: 12h
      # 🔧 开发环境: 较短的告警保留期
```

---

## 🎯 环境管理策略

### 端口分配标准
| 服务 | DEV环境 | SIT环境 | 说明 |
|------|---------|---------|------|
| Grafana | 30080 | 30081 | 监控面板 |
| Prometheus | 30090 | 30091 | 指标收集 |
| AlertManager | 30093 | 30094 | 告警管理 |

### 配置分层设计
```yaml
# 🌟 三层配置模式
# 1. Base Layer (charts/*/values.yaml) - 默认配置
# 2. Environment Layer (environments/*/values.yaml) - 环境覆盖
# 3. Runtime Layer (ConfigMap/Secret) - 运行时配置
```

### 存储类统一配置 ⚠️
所有环境统一使用 `storageClassName: "local-path"`:
- **charts/kube-prometheus-stack/values.yaml**: 基础配置已修复
- **environments/staging/kube-prometheus-stack-values.yaml**: staging环境已修复
- **environments/dev/kube-prometheus-stack-values.yaml**: DEV环境正确配置
- **environments/sit/kube-prometheus-stack-values.yaml**: SIT环境正确配置

---

## 🚀 部署验证流程

### 1. 检查存储类
```bash
kubectl get storageclass
# 确保存在 local-path (default)
```

### 2. 部署App-of-Apps
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

### 3. 验证应用状态
```bash
# 检查ArgoCD应用
kubectl get applications -n argocd

# 检查Pod状态
kubectl get pods -n microservice1-dev
kubectl get pods -n microservice2-dev  
kubectl get pods -n monitoring
```

### 4. 访问监控服务
```bash
# 获取公网IP
export PUBLIC_IP=$(curl -s ifconfig.me)

# 访问地址
echo "Grafana: http://$PUBLIC_IP:30080 (admin/devadmin123)"
echo "Prometheus: http://$PUBLIC_IP:30090"
echo "AlertManager: http://$PUBLIC_IP:30093"
```

---

## 🎯 学习要点总结

### 🌟 GitOps核心模式
1. **App-of-Apps**: 一个根应用管理所有子应用
2. **声明式配置**: 所有配置都在Git中声明
3. **自动同步**: ArgoCD检测变更并自动部署
4. **环境隔离**: 通过命名空间和配置分层实现

### 🔧 Helm模板化
1. **模板复用**: 一套Chart支持多环境部署
2. **配置分离**: 模板与环境配置分离管理
3. **动态渲染**: 根据Values动态生成Kubernetes资源
4. **条件控制**: 通过if/range实现灵活的模板逻辑

### 📊 监控集成
1. **ServiceMonitor**: 自动发现微服务监控端点
2. **标签选择**: 通过release标签被Prometheus发现
3. **多环境支持**: 不同环境使用不同端口和配置
4. **存储统一**: 所有组件使用local-path存储类

### ⚠️ 配置关键点
1. **StorageClass统一**: 必须使用"local-path"避免PVC冲突
2. **标签一致性**: ServiceMonitor的release标签必须正确
3. **端口规划**: 不同环境使用不同NodePort避免冲突
4. **镜像认证**: 所有命名空间需要ghcr-secret