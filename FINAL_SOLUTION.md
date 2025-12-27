# Helm + Kustomize 组合最终方案

## 问题分析

1. **helmCharts 字段不支持本地路径**：`helmCharts.path` 不支持本地 .tgz 文件或目录
2. **Application 中同时指定 helm 和 kustomize 不工作**：ArgoCD 会优先识别为 Helm，不会使用 Kustomize 处理
3. **需要动态注入 annotations**：对于第三方 Chart，不能修改 templates

## 解决方案

### 方案一：使用远程 Chart 仓库（推荐）

如果 Chart 是第三方的，应该已经有远程仓库。在 `kustomization.yaml` 中使用：

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: chart-name
    repo: https://charts.example.com  # Chart 仓库 URL
    version: 1.0.0
    releaseName: hello-app
    namespace: default

commonAnnotations:
  managed-by: argocd
  generated-by: "helm+kustomize"
```

### 方案二：使用本地 Chart 仓库（ChartMuseum）

1. 安装 ChartMuseum
2. 上传 Chart 到 ChartMuseum
3. 在 `kustomization.yaml` 中使用 ChartMuseum 的 URL

### 方案三：使用 ArgoCD Application 的 post-render（需要验证）

ArgoCD 可能支持 post-render hook，但这需要特殊配置。

### 方案四：直接在 Helm templates 中添加（不符合需求）

如果 Chart 可以修改，直接在 templates 中添加 annotations，但这不符合"第三方 Chart 不能修改"的需求。

## 当前测试配置

当前配置使用 `resources: - charts/hello`，但这不会使用 Helm 渲染，而是直接使用 Kustomize 处理 Chart 目录。这种方式：
- ✅ 可以添加 annotations 和 labels
- ❌ 不会使用 Helm 的 values.yaml
- ❌ 不会使用 Helm 的模板功能

## 建议

对于第三方 Chart，最佳实践是：
1. **使用远程 Chart 仓库**：在 `kustomization.yaml` 中使用 `helmCharts` 的 `repo` + `version`
2. **Application 中只指定 kustomize**：不要指定 helm
3. **启用 `--enable-helm`**：让 Kustomize 能够渲染 Helm Chart

## 验证步骤

```bash
# 1. 检查 Application 配置
kubectl get application hello-app -n argocd -o json | jq '.spec.source'

# 2. 检查 Source Type（应该是 Kustomize）
kubectl get application hello-app -n argocd -o jsonpath='{.status.sourceType}'

# 3. 检查资源是否包含 annotations
kubectl get deployment hello-app -n default -o yaml | grep -A 5 "annotations:"
```

