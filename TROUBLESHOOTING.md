# 故障排查指南

## 常见错误

### 错误：application destination can't have both name and server defined

**错误信息**：
```
application destination can't have both name and server defined: in-cluster https://kubernetes.default.svc
```

**原因**：
ArgoCD Application 的 `destination` 配置中不能同时指定 `name` 和 `server`。只能使用其中一种方式：
- 使用 `server`：直接指定集群的 API Server URL
- 使用 `name`：使用在 ArgoCD 中注册的集群名称

**解决方案**：

1. **方法一：移除 name，只使用 server**（推荐）
   ```yaml
   destination:
     server: https://kubernetes.default.svc
     namespace: default
     # 不要同时指定 name
   ```

2. **方法二：移除 server，只使用 name**
   ```yaml
   destination:
     name: in-cluster
     namespace: default
     # 需要先在 ArgoCD 中注册名为 "in-cluster" 的集群
   ```

**修复命令**：
```bash
# 移除 name 字段
kubectl patch application hello-app -n argocd --type json \
  -p='[{"op": "remove", "path": "/spec/destination/name"}]'

# 或者使用完整的配置更新
kubectl apply -f argocd-application.yaml
```

**验证修复**：
```bash
# 检查 destination 配置
kubectl get application hello-app -n argocd -o jsonpath='{.spec.destination}'

# 应该只看到 server 和 namespace，没有 name
# 正确输出：{"namespace":"default","server":"https://kubernetes.default.svc"}
```

### 错误：Source Type 显示为 "Directory" 而不是 "Kustomize"

**原因**：ArgoCD 没有识别到 `kustomization.yaml` 文件

**解决方案**：
1. 检查文件名是否正确：`kustomization.yaml`（不是 `kustomization.yml`）
2. 检查文件是否在正确的路径
3. 确保 Application 的 `path` 指向包含 `kustomization.yaml` 的目录

### 错误：同步失败 - 找不到资源

**原因**：资源定义有问题或路径不正确

**解决方案**：
1. 检查 `kustomization.yaml` 中的 `resources` 列表
2. 确保所有引用的文件都存在
3. 检查 YAML 语法是否正确

### 错误：无法连接到 Git 仓库

**原因**：Git 仓库认证失败或 URL 不正确

**解决方案**：
1. 检查仓库 URL 是否正确
2. 在 ArgoCD 中配置仓库认证（Settings -> Repositories）
3. 检查网络连接

## 调试命令

```bash
# 查看应用详细状态
kubectl get application hello-app -n argocd -o yaml

# 查看应用同步状态
kubectl get application hello-app -n argocd -o jsonpath='{.status.sync.status}'

# 查看应用健康状态
kubectl get application hello-app -n argocd -o jsonpath='{.status.health.status}'

# 查看同步历史
kubectl get application hello-app -n argocd -o jsonpath='{.status.history[*].revision}'

# 查看 repo-server 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100 | grep hello-app

# 查看应用控制器日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 | grep hello-app
```

## 重置应用

如果应用配置出现问题，可以删除并重新创建：

```bash
# 删除应用（不会删除已部署的资源）
kubectl delete application hello-app -n argocd

# 重新创建
kubectl apply -f argocd-application.yaml
```

## 获取帮助

- ArgoCD 官方文档：https://argo-cd.readthedocs.io/
- ArgoCD GitHub Issues：https://github.com/argoproj/argo-cd/issues

