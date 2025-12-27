# Helm + Kustomize 组合配置说明

## 目录结构

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

## 工作流程

1. **Helm 渲染**：Helm 根据 `templates/` 和 `values.yaml` 生成 Kubernetes 资源
2. **Kustomize 处理**：Kustomize 对 Helm 生成的资源添加 annotations 和 labels
3. **ArgoCD 同步**：ArgoCD 将最终资源同步到集群

## ArgoCD 配置

### 1. 启用 Kustomize 的 Helm 支持

需要在 ArgoCD ConfigMap 中启用：

```bash
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

# 重启 repo-server 使配置生效
kubectl rollout restart deployment argocd-repo-server -n argocd
```

### 2. Application 配置

Application 配置中需要同时指定 Helm 和 Kustomize：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: https://github.com/unhejing/hello.git
    path: .
    helm:
      releaseName: hello-app
    # Kustomize 会自动处理 Helm 生成的资源
```

## 验证配置

### 1. 本地测试 Helm Chart

```bash
# 测试 Helm 模板渲染
helm template hello-app . --debug

# 测试 Helm 安装（dry-run）
helm install hello-app . --dry-run --debug
```

### 2. 测试 Kustomize

```bash
# 先渲染 Helm
helm template hello-app . > /tmp/helm-output.yaml

# 然后使用 Kustomize 处理（需要先配置）
# 注意：实际使用中 ArgoCD 会自动处理
```

### 3. 在 ArgoCD 中验证

```bash
# 查看应用的 Source Type
kubectl get application hello-app -n argocd -o jsonpath='{.status.sourceType}'

# 查看应用的配置
kubectl get application hello-app -n argocd -o yaml | grep -A 10 "source:"
```

## 注意事项

1. **优先级**：如果同时存在 `Chart.yaml` 和 `kustomization.yaml`，ArgoCD 会优先识别为 Helm
2. **Annotations**：Kustomize 添加的 annotations 会覆盖 Helm 模板中的同名 annotations
3. **Labels**：`commonLabels` 会合并到 Helm 生成的 labels 中
4. **命名空间**：确保 Helm 和 Kustomize 使用相同的命名空间

## 常见问题

### Q: Source Type 显示为 Helm 而不是 Kustomize？
**A:** 这是正常的。ArgoCD 会先识别为 Helm，然后使用 Kustomize 处理 Helm 生成的资源。

### Q: 如何查看最终生成的资源？
**A:** 在 ArgoCD UI 中，点击应用 -> "App Details" -> "Manifest"，可以看到最终生成的资源（包含 Kustomize 添加的 annotations）。

### Q: 如何修改配置？
**A:** 
- 修改 Helm 配置：编辑 `values.yaml`
- 修改 Kustomize annotations：编辑 `kustomization.yaml`
- 修改模板：编辑 `templates/` 目录下的文件

## 更新流程

1. 修改 `values.yaml` 或 `templates/` 中的文件
2. 提交到 Git 仓库
3. ArgoCD 自动检测变更（如果配置了自动同步）
4. Helm 重新渲染资源
5. Kustomize 添加 annotations
6. 资源同步到集群

