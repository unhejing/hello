# ArgoCD 自动同步说明

## 当前配置状态

你的 `argocd-application.yaml` 已经配置了自动同步：

```yaml
syncPolicy:
  automated:
    prune: true      # 自动删除 Git 中已删除的资源
    selfHeal: true   # 自动修复手动修改的资源
```

## 自动同步的工作原理

### 1. 自动检测 Git 变更
ArgoCD 会定期轮询 Git 仓库（默认每 3 分钟），检测是否有新的提交。

### 2. 自动同步条件
- ✅ Git 仓库有新的提交
- ✅ 应用配置了 `syncPolicy.automated`
- ✅ 应用处于 Healthy 状态

### 3. 同步延迟
- **默认轮询间隔**：3 分钟
- 这意味着推送代码后，最多需要等待 3 分钟才会自动同步

## 如何验证自动同步是否工作

### 方法一：查看应用状态

```bash
# 查看应用的同步历史
kubectl get application hello-app -n argocd -o jsonpath='{.status.history[*].revision}'

# 查看最后一次同步时间
kubectl get application hello-app -n argocd -o jsonpath='{.status.sync.status}'
```

### 方法二：在 ArgoCD UI 中查看

1. 登录 ArgoCD UI
2. 点击应用 `hello-app`
3. 查看 "App Details" -> "History"
4. 应该能看到每次 Git 提交后的自动同步记录

### 方法三：测试自动同步

```bash
# 1. 修改代码并推送
cd /Users/rocky/project/common/docs/argocd/hello
# 修改 configmap.yaml 中的内容
git add .
git commit -m "Test auto sync"
git push

# 2. 等待 3 分钟后，检查是否自动同步
# 或者立即手动触发同步（用于测试）
argocd app sync hello-app

# 3. 查看同步状态
kubectl get application hello-app -n argocd -o yaml | grep -A 5 "sync:"
```

## 如何立即触发同步（不等待轮询）

### 方法一：使用 ArgoCD CLI

```bash
# 手动触发同步
argocd app sync hello-app

# 或者使用 kubectl
kubectl patch application hello-app -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### 方法二：在 ArgoCD UI 中

1. 点击应用 `hello-app`
2. 点击 "Sync" 按钮
3. 选择同步选项，点击 "Synchronize"

### 方法三：配置 Webhook（推荐，实现即时同步）

配置 Git Webhook 可以在推送代码后立即触发同步，无需等待轮询。

#### GitHub Webhook 配置

1. **在 GitHub 仓库中配置 Webhook**
   - 进入仓库 Settings -> Webhooks -> Add webhook
   - Payload URL: `https://<argocd-server-url>/api/webhook`
   - Content type: `application/json`
   - Events: 选择 "Just the push event"
   - Active: 勾选

2. **获取 ArgoCD Webhook URL**

```bash
# 查看 ArgoCD Server 的地址
kubectl get svc -n argocd argocd-server

# 如果使用 port-forward，webhook URL 为：
# https://localhost:9443/api/webhook
```

3. **配置 Webhook Secret（可选但推荐）**

```bash
# 生成随机 secret
openssl rand -base64 32

# 在 ArgoCD 中配置
kubectl patch secret argocd-secret -n argocd --type json \
  -p='[{"op": "add", "path": "/data/webhook.github.secret", "value": "'$(echo -n "your-secret" | base64)'"}]'
```

#### 在 Application 中启用 Webhook

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-app
  namespace: argocd
  annotations:
    # 启用 GitHub webhook
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
spec:
  # ... 其他配置
```

## 检查自动同步是否启用

```bash
# 检查应用的同步策略
kubectl get application hello-app -n argocd -o jsonpath='{.spec.syncPolicy.automated}'

# 如果有输出（不是空的），说明已启用自动同步
# 输出应该类似：{"prune":true,"selfHeal":true}
```

## 常见问题

### Q: 推送代码后没有自动同步？
**A: 检查以下几点：**
1. 确认 `syncPolicy.automated` 已配置
2. 等待 3 分钟（默认轮询间隔）
3. 检查应用是否处于 Healthy 状态
4. 查看 repo-server 日志：
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50 | grep hello-app
   ```

### Q: 如何缩短轮询间隔？
**A: 修改 ArgoCD 配置：**
```bash
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"timeout.reconciliation":"60s"}}'
```

### Q: 如何禁用自动同步？
**A: 移除或修改 syncPolicy：**
```yaml
syncPolicy:
  automated: null  # 或删除整个 syncPolicy 块
```

## 推荐配置

对于生产环境，推荐配置：

```yaml
syncPolicy:
  automated:
    prune: true           # 自动清理已删除的资源
    selfHeal: true        # 自动修复手动修改
    allowEmpty: false     # 不允许空同步
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

## 总结

- ✅ 你的配置已经启用了自动同步
- ⏱️ 推送代码后，ArgoCD 会在 3 分钟内自动检测并同步
- 🚀 如需即时同步，可以配置 Webhook 或手动触发同步
- 📊 在 ArgoCD UI 的 "History" 中可以查看所有同步记录

