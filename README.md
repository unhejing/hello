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

