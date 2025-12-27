# Helm + Kustomize 组合配置说明

## 目录结构

```
hello/
├── Chart.yaml              # Helm Chart 定义
├── values.yaml             # Helm 值文件
├── kustomization.yaml      # Kustomize 配置（使用 helmCharts 字段）
├── charts/                 # 子 Chart 目录（可选）
└── templates/              # Helm 模板目录
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    ├── _helper.tpl         # 辅助模板
    └── NOTES.txt           # 安装后提示
```

## 工作流程

1. **Kustomize 渲染 Helm Chart**：Kustomize 使用 `helmCharts` 字段渲染 Helm Chart
2. **Kustomize 处理资源**：Kustomize 对渲染后的资源添加 annotations 和 labels
3. **ArgoCD 同步**：ArgoCD 将最终资源同步到集群

## ArgoCD 配置

### 1. 启用 Kustomize 的 Helm 支持（必须！）

**这是关键步骤**，必须执行：

```bash
# 启用 Kustomize 对 Helm 的支持
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

# 重启 repo-server 使配置生效
kubectl rollout restart deployment argocd-repo-server -n argocd

# 等待 repo-server 重启完成
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=60s
```

### 2. Application 配置

**重要**：Application 配置中**只指定 Kustomize**，不要指定 Helm：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: https://github.com/unhejing/hello.git
    path: .
    # 只指定 kustomize，不要指定 helm
    kustomize:
      # Kustomize 会自动读取 kustomization.yaml
      # kustomization.yaml 中的 helmCharts 字段会渲染 Helm Chart
```

### 3. kustomization.yaml 配置

在 `kustomization.yaml` 中使用 `helmCharts` 字段：

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: hello
    path: .  # 本地 Chart 路径
    releaseName: hello-app
    namespace: default

# 添加 annotations 和 labels
commonAnnotations:
  managed-by: argocd
  generated-by: "helm+kustomize"

commonLabels:
  managed-by: argocd
  generated-by: "helm+kustomize"
```

## 验证配置

### 1. 验证 ArgoCD 配置

```bash
# 检查是否启用了 --enable-helm
kubectl get configmap argocd-cm -n argocd -o yaml | grep kustomize.buildOptions

# 应该看到：kustomize.buildOptions: --enable-helm
```

### 2. 本地测试 Kustomize（需要先启用 --enable-helm）

```bash
# 测试 Kustomize 渲染（需要 kustomize 命令）
kubectl kustomize . --enable-helm

# 或者使用 ArgoCD repo-server 测试
# 在 ArgoCD UI 中创建应用后，查看生成的资源
```

### 3. 在 ArgoCD 中验证

```bash
# 查看应用的 Source Type（应该是 Kustomize）
kubectl get application hello-app -n argocd -o jsonpath='{.status.sourceType}'

# 查看应用的配置
kubectl get application hello-app -n argocd -o yaml | grep -A 10 "source:"

# 查看最终生成的资源（应该包含 Kustomize 添加的 annotations）
kubectl get deployment hello-app -n default -o yaml | grep -A 5 "annotations:"
```

### 4. 验证 annotations 是否生效

```bash
# 检查 Deployment 是否有 Kustomize 添加的 annotations
kubectl get deployment hello-app -n default -o jsonpath='{.metadata.annotations}' | jq .

# 应该看到：
# - managed-by: argocd
# - generated-by: helm+kustomize
# - argocd.argoproj.io/sync-wave: "0"
```

## 注意事项

1. **必须启用 `--enable-helm`**：这是让 Kustomize 处理 Helm Chart 的关键
2. **Application 只指定 Kustomize**：不要同时指定 `helm` 和 `kustomize`
3. **使用 helmCharts 字段**：在 `kustomization.yaml` 中使用 `helmCharts` 字段引用 Helm Chart
4. **路径问题**：`helmCharts.path` 是相对于 `kustomization.yaml` 的路径
5. **第三方 Chart**：如果 Chart 在 `charts/` 目录下，使用 `path: charts/chart-name`

## 常见问题

### Q: Source Type 显示为 Helm 而不是 Kustomize？
**A:** 检查 Application 配置，确保只指定了 `kustomize`，没有指定 `helm`。

### Q: Kustomize 没有处理 Helm Chart？
**A:** 检查是否启用了 `kustomize.buildOptions: --enable-helm`，并重启了 repo-server。

### Q: 如何引用第三方 Helm Chart？
**A:** 在 `helmCharts` 中使用 `repo` 和 `version` 字段：
```yaml
helmCharts:
  - name: nginx
    repo: https://charts.bitnami.com/bitnami
    version: 15.0.0
    releaseName: nginx
```

### Q: 如何验证配置是否正确？
**A:** 
1. 检查 ArgoCD ConfigMap 是否启用了 `--enable-helm`
2. 检查 Application 的 Source Type 是否为 Kustomize
3. 检查最终生成的资源是否包含 Kustomize 添加的 annotations

## 更新流程

1. 修改 `values.yaml` 或 `templates/` 中的文件
2. 修改 `kustomization.yaml` 中的 annotations 或 labels
3. 提交到 Git 仓库
4. ArgoCD 自动检测变更（如果配置了自动同步）
5. Kustomize 渲染 Helm Chart
6. Kustomize 添加 annotations
7. 资源同步到集群
