# 验证 Kustomize 是否生效

## 验证方法

### 方法一：在 ArgoCD UI 中查看

1. **登录 ArgoCD UI**
   ```bash
   kubectl port-forward -n argocd svc/argocd-server-nodeport 9443:443
   # 访问 https://localhost:9443
   ```

2. **查看应用详情**
   - 点击应用 `hello-app`
   - 查看 "Source Type" 应该显示为 **"Kustomize"**（不是 "Directory"）
   - 点击 "App Details" -> "Source" 可以看到 Kustomize 配置

3. **查看生成的资源**
   - 在应用详情页面，点击 "Resource" 标签
   - 应该能看到两个 ConfigMap：
     - `hello-html`（静态 ConfigMap）
     - `hello-env-config-xxxxx`（Kustomize 动态生成的，带随机后缀）

4. **查看 Manifest**
   - 点击 "App Details" -> "Manifest"
   - 搜索 `hello-env-config`，应该能看到动态生成的 ConfigMap
   - 检查是否有 `generated-by: kustomize` 标签

### 方法二：使用 kubectl 命令验证

```bash
# 1. 查看所有 ConfigMap（应该看到动态生成的）
kubectl get configmap -n default | grep hello

# 输出应该类似：
# hello-env-config-xxxxx   1      2m    # 这个是 Kustomize 动态生成的
# hello-html               1      2m    # 这个是静态的

# 2. 查看动态生成的 ConfigMap 内容
kubectl get configmap -n default -l generated-by=kustomize -o yaml

# 3. 查看 ConfigMap 的详细信息
kubectl describe configmap hello-env-config-xxxxx -n default

# 4. 验证 Pod 中是否注入了环境变量
kubectl get pods -n default -l app=hello-app
POD_NAME=$(kubectl get pods -n default -l app=hello-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n default $POD_NAME -- env | grep -E "APP_NAME|DEPLOYED_BY"

# 5. 查看 Pod 中挂载的 ConfigMap
kubectl describe pod $POD_NAME -n default | grep -A 5 "Mounts:"
```

### 方法三：查看 ArgoCD 生成的 Manifest

```bash
# 使用 ArgoCD CLI（如果已安装）
argocd app get hello-app -o yaml | grep -A 20 "hello-env-config"

# 或者查看应用的 Manifest
argocd app manifests hello-app | grep -A 10 "hello-env-config"
```

### 方法四：验证 Kustomize 功能特性

```bash
# 1. 检查是否有 commonLabels（所有资源应该有 managed-by: argocd 标签）
kubectl get all -n default -l managed-by=argocd

# 2. 检查命名空间是否正确应用
kubectl get deployment hello-app -n default -o jsonpath='{.metadata.namespace}'
# 应该输出：default

# 3. 查看 Deployment 的完整配置（应该包含 Kustomize 生成的标签）
kubectl get deployment hello-app -n default -o yaml | grep -A 5 labels
```

## 验证清单

- [ ] ArgoCD UI 中 Source Type 显示为 "Kustomize"
- [ ] 能看到动态生成的 ConfigMap `hello-env-config-xxxxx`
- [ ] ConfigMap 有 `generated-by: kustomize` 标签
- [ ] Pod 中能读取到环境变量 `APP_NAME` 和 `DEPLOYED_BY`
- [ ] 所有资源都有 `managed-by: argocd` 标签
- [ ] 所有资源都在 `default` 命名空间

## 如果验证失败

### 问题：Source Type 显示为 "Directory" 而不是 "Kustomize"
**原因**：ArgoCD 没有识别到 `kustomization.yaml`
**解决**：
1. 检查文件名是否正确：`kustomization.yaml`（不是 `kustomization.yml`）
2. 检查文件是否在正确的路径
3. 在 ArgoCD Application 中，确保 Path 指向包含 `kustomization.yaml` 的目录

### 问题：看不到动态生成的 ConfigMap
**原因**：Kustomize 没有执行
**解决**：
1. 检查 `kustomization.yaml` 语法是否正确
2. 查看 ArgoCD repo-server 日志：
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100 | grep -i kustomize
   ```
3. 在 ArgoCD UI 中查看应用的 "Conditions" 是否有错误

### 问题：Pod 中读取不到环境变量
**原因**：Deployment 配置可能有问题
**解决**：
1. 检查 Deployment 中的 `env` 配置
2. 确认 ConfigMap 名称是否正确（注意 Kustomize 会添加后缀）
3. 重启 Pod：
   ```bash
   kubectl rollout restart deployment hello-app -n default
   ```

## 快速验证脚本

```bash
#!/bin/bash
echo "=== 验证 Kustomize 是否生效 ==="
echo ""

echo "1. 检查 ConfigMap（应该看到 hello-env-config-xxxxx）"
kubectl get configmap -n default | grep hello
echo ""

echo "2. 检查动态生成的 ConfigMap 标签"
kubectl get configmap -n default -l generated-by=kustomize
echo ""

echo "3. 检查 Pod 环境变量"
POD_NAME=$(kubectl get pods -n default -l app=hello-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    echo "Pod: $POD_NAME"
    kubectl exec -n default $POD_NAME -- env | grep -E "APP_NAME|DEPLOYED_BY" || echo "环境变量未找到"
else
    echo "Pod 未找到"
fi
echo ""

echo "4. 检查所有资源的标签"
kubectl get all -n default -l managed-by=argocd
echo ""

echo "验证完成！"
```

