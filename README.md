# Hello App - ArgoCD 测试项目

这是一个简单的测试应用，用于验证 ArgoCD 的部署功能。

## 项目结构

```
hello/
├── deployment.yaml      # Deployment 配置
├── service.yaml        # Service 配置
├── configmap.yaml      # ConfigMap 配置（包含 HTML 页面）
├── kustomization.yaml  # Kustomize 配置（可选）
└── README.md          # 说明文档
```

## 手动部署

```bash
# 应用所有资源（在 hello 目录下执行）
kubectl apply -f .

# 查看部署状态
kubectl get pods -l app=hello-app
kubectl get svc hello-app

# 访问应用（需要 port-forward）
kubectl port-forward svc/hello-app 8080:80
# 然后访问 http://localhost:8080
```

## 通过 ArgoCD 部署

### 1. 创建 ArgoCD Application

```bash
kubectl apply -f argocd-application.yaml
```

或者通过 ArgoCD UI：
1. 登录 ArgoCD
2. 点击 "New App"
3. 配置：
   - Application Name: `hello-app`
   - Project: `default`
   - Sync Policy: `Manual` 或 `Automatic`
   - Repository URL: 你的 Git 仓库地址
   - Path: `.`
   - Cluster: `in-cluster`
   - Namespace: `default`

### 2. 同步应用

在 ArgoCD UI 中点击 "Sync" 按钮，或使用 CLI：

```bash
argocd app sync hello-app
```

### 3. 查看应用状态

```bash
argocd app get hello-app
```

## 访问应用

```bash
# 使用 port-forward
kubectl port-forward svc/hello-app 8080:80

# 访问 http://localhost:8080
```

## 更新应用

修改 `configmap.yaml` 中的 HTML 内容，提交到 Git 仓库，ArgoCD 会自动检测并同步（如果配置了自动同步）。

## 验证 Kustomize 是否生效

### 快速验证

```bash
# 1. 查看动态生成的 ConfigMap（Kustomize 会添加随机后缀）
kubectl get configmap -n default | grep hello-env-config

# 2. 查看 Pod 中的环境变量
POD_NAME=$(kubectl get pods -n default -l app=hello-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n default $POD_NAME -- env | grep -E "APP_NAME|DEPLOYED_BY"

# 3. 检查所有资源是否有 managed-by: argocd 标签
kubectl get all -n default -l managed-by=argocd
```

### 在 ArgoCD UI 中验证

1. 登录 ArgoCD UI
2. 点击应用 `hello-app`
3. 查看 "Source Type" 应该显示为 **"Kustomize"**（不是 "Directory"）
4. 在 "Resource" 标签中，应该能看到 `hello-env-config-xxxxx` ConfigMap（动态生成的）

详细验证方法请查看 [VERIFY.md](./VERIFY.md)

