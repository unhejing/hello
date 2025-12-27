# Hello App - ArgoCD 测试项目（Helm + Kustomize）

这是一个使用 Helm + Kustomize 组合方式的测试应用，用于验证 ArgoCD 的部署功能。

## 项目结构

```
hello/
├── Chart.yaml              # Helm Chart 定义
├── values.yaml             # Helm 值文件
├── kustomization.yaml      # Kustomize 配置（添加 annotations）
├── charts/                 # 子 Chart 目录（可选）
└── templates/              # Helm 模板目录
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    ├── _helper.tpl         # 辅助模板
    └── NOTES.txt           # 安装后提示
```

**说明**：本项目使用 Helm + Kustomize 组合方式：
- **Helm**：管理 Kubernetes 资源模板和配置
- **Kustomize**：对 Helm 生成的资源添加 annotations 和 labels

详细配置说明请查看 [HELM_KUSTOMIZE_SETUP.md](./HELM_KUSTOMIZE_SETUP.md)

## 手动部署

### 使用 Helm 部署

```bash
# 测试 Helm 模板渲染
helm template hello-app .

# 安装（dry-run 测试）
helm install hello-app . --dry-run --debug

# 实际安装
helm install hello-app .

# 查看部署状态
kubectl get pods -l app=hello-app
kubectl get svc hello-app

# 访问应用（需要 port-forward）
kubectl port-forward svc/hello-app 8080:80
# 然后访问 http://localhost:8080
```

### 使用 kubectl 直接部署（不推荐）

```bash
# 先渲染 Helm，然后应用
helm template hello-app . | kubectl apply -f -
```

## 通过 ArgoCD 部署

### 1. 创建 ArgoCD Application

**方式一：通过 ArgoCD UI（推荐）**
1. 登录 ArgoCD
2. 点击 "New App"
3. 配置：
   - Application Name: `hello-app`
   - Project: `default`
   - Sync Policy: `Manual` 或 `Automatic`
   - Repository URL: 你的 Git 仓库地址
   - Path: `.`
   - Source Type: 选择 **Helm**（ArgoCD 会自动识别 Chart.yaml）
   - Helm Release Name: `hello-app`
   - Cluster: `in-cluster` 或 `https://kubernetes.default.svc`
   - Namespace: `default`

**注意**：ArgoCD 会自动识别为 Helm 应用（因为有 Chart.yaml），然后使用 Kustomize 处理 Helm 生成的资源。

**方式二：使用 YAML 文件（可选）**

```bash
# 如果应用已在 UI 中创建，这个文件仅作为配置参考
# 如果需要用文件创建/更新应用：
kubectl apply -f argocd-application.yaml
```

**注意**：`argocd-application.yaml` 文件是可选的，主要用于：
- 配置备份和文档
- 版本控制和团队共享
- 快速重建应用

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

### 修改 Helm 配置

修改 `values.yaml` 中的配置，提交到 Git 仓库，ArgoCD 会自动检测并同步。

### 修改模板

修改 `templates/` 目录下的模板文件，提交到 Git 仓库。

### 修改 Kustomize 配置

修改 `kustomization.yaml` 中的 annotations 或 labels，提交到 Git 仓库。

**自动同步说明**：
- ✅ 已配置自动同步（`syncPolicy.automated`）
- ⏱️ ArgoCD 每 3 分钟轮询一次 Git 仓库
- 🚀 推送代码后，最多等待 3 分钟会自动同步
- 📝 详细说明请查看 [AUTO_SYNC.md](./AUTO_SYNC.md)

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

# 4. 检查资源是否有 Kustomize 添加的 annotations
kubectl get deployment hello-app -n default -o yaml | grep annotations
```

### 在 ArgoCD UI 中验证

1. 登录 ArgoCD UI
2. 点击应用 `hello-app`
3. 查看 "Source Type" 应该显示为 **"Helm"**（因为优先识别 Helm）
4. 在 "Resource" 标签中，查看资源是否有 Kustomize 添加的 annotations

详细验证方法请查看 [VERIFY.md](./VERIFY.md)

## Helm + Kustomize 组合说明

本项目使用 Helm + Kustomize 组合方式：
- **Helm**：管理资源模板和配置（`templates/` + `values.yaml`）
- **Kustomize**：对 Helm 生成的资源添加 annotations 和 labels

详细配置说明请查看 [HELM_KUSTOMIZE_SETUP.md](./HELM_KUSTOMIZE_SETUP.md)
